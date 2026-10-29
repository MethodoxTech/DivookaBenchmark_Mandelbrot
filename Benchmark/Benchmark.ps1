<#
.SYNOPSIS
Runs one benchmark's programs in alternation, and reports each one's median time, its range and its peak memory.

.DESCRIPTION
Every program runs once per round, in an order that turns by one place each round, so whatever else the machine does - a build, an update, the fans stepping up - lands on every program rather than on whichever was running at the time. Each run is a process of its own, started with its standard input closed (a program that waits for input would otherwise wait for ever); its time is the wall clock from starting the process to its exit, so a runtime's start-up is part of it, and its memory is the peak working set Windows recorded for the process.

A run counts only if its answer is right. The reference program (C# AoT) runs first on every size used, and every other run must print the same checksum - and for the ray tracer, write a picture whose SHA-256 is the reference's. A wrong answer is reported and kept out of the figures.

A program too slow to run at full size is estimated: it runs at two smaller sizes, and the full size's time is read off the straight line through the two, by the work each size does - the iterations a Mandelbrot run makes, which is its checksum, or the primary rays the ray tracer traces. An estimate is labelled as one.

The browser is timed by the page itself, render only: Chrome runs it headless and the harness reads what it printed.

Build the compiled programs first (Build.ps1). Tools are found on PATH unless an environment variable names them: BENCH_JAVA (else JAVA_HOME's java), BENCH_NODE, BENCH_JULIA, BENCH_PYTHON, BENCH_RUBY, BENCH_PERL, BENCH_ERL and BENCH_ELIXIR (the Elixir folder holding lib), BENCH_SWIPL, BENCH_OCTAVE (octave-cli), BENCH_PURE (Divooka Pure 2's Pure.exe), BENCH_STEW (stew.exe in a Divooka Compute folder), BENCH_SPY and BENCH_SPY_AOT (SteelPython's spy.exe, from its full and its embedded Native AOT distribution) and BENCH_CHROME. A program whose tool is not found is skipped and said so.

.PARAMETER Benchmark
Mandelbrot (2000 x 2000, 1000 iterations) or RayTracer (RayTracer/scene.txt).

.PARAMETER Rounds
Rounds for the programs that take seconds.

.PARAMETER SlowRounds
Rounds for the programs marked slow, and for each size an estimate runs.

.PARAMETER Only
Run only these programs (by name, wildcards allowed). The reference always runs.

.PARAMETER Skip
Leave out these programs (by name, wildcards allowed).

.EXAMPLE
pwsh Benchmark/Benchmark.ps1 -Benchmark RayTracer -Rounds 5
#>
[CmdletBinding()]
param(
    [ValidateSet('Mandelbrot', 'RayTracer')] [string] $Benchmark = 'Mandelbrot',
    [int] $Rounds = 5,
    [int] $SlowRounds = 3,
    [string[]] $Only,
    [string[]] $Skip,
    [string] $Results = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Results'),
    [int] $TimeoutMinutes = 180
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root "Artifacts/Build/$Benchmark"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$work = Join-Path $Results "$Benchmark-$stamp"
New-Item -ItemType Directory -Force $work | Out-Null

#region Running a process
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class BenchmarkProcess
{
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryCounters
    {
        public uint Size, PageFaultCount;
        public UIntPtr PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage, QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage, PagefileUsage, PeakPagefileUsage;
    }
    [DllImport("psapi.dll", SetLastError = true)]
    private static extern bool GetProcessMemoryInfo(IntPtr process, out MemoryCounters counters, uint size);

    public sealed class Outcome
    {
        public int ExitCode;
        public bool TimedOut;
        public double Milliseconds;
        public double PeakWorkingSetMB;
        public string Output = "";
        public string Error = "";
    }

    /// <summary>Runs a program to its exit with its standard input closed, timing it from start to exit and reading its peak working set before the handle is let go.</summary>
    public static Outcome Run(string file, string[] arguments, string directory, int timeoutMilliseconds)
    {
        ProcessStartInfo start = new ProcessStartInfo(file)
        {
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = directory,
        };
        foreach (string argument in arguments)
            start.ArgumentList.Add(argument);
        Outcome outcome = new Outcome();
        Stopwatch clock = Stopwatch.StartNew();
        using (Process process = Process.Start(start))
        {
            process.StandardInput.Close();
            System.Threading.Tasks.Task<string> output = process.StandardOutput.ReadToEndAsync();
            System.Threading.Tasks.Task<string> error = process.StandardError.ReadToEndAsync();
            if (!process.WaitForExit(timeoutMilliseconds))
            {
                outcome.TimedOut = true;
                process.Kill(true);
            }
            process.WaitForExit();
            clock.Stop();
            MemoryCounters counters;
            if (GetProcessMemoryInfo(process.Handle, out counters, (uint)Marshal.SizeOf(typeof(MemoryCounters))))
                outcome.PeakWorkingSetMB = counters.PeakWorkingSetSize.ToUInt64() / (1024.0 * 1024.0);
            outcome.ExitCode = process.ExitCode;
            outcome.Output = output.Result;
            outcome.Error = error.Result;
        }
        outcome.Milliseconds = clock.Elapsed.TotalMilliseconds;
        return outcome;
    }
}
'@
#endregion

#region Tools
function Find-Tool([string] $variable, [string[]] $names, [string] $fallback)
{
    $named = [Environment]::GetEnvironmentVariable($variable)
    if ($named) { return $named }
    if ($fallback -and (Test-Path $fallback)) { return $fallback }
    foreach ($name in $names)
    {
        $found = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.Source }
    }
    return $null
}
$tools = @{
    Java   = Find-Tool BENCH_JAVA @('java') $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' })
    Node   = Find-Tool BENCH_NODE @('node')
    Julia  = Find-Tool BENCH_JULIA @('julia')
    Python = Find-Tool BENCH_PYTHON @('python')
    Ruby   = Find-Tool BENCH_RUBY @('ruby')
    Perl   = Find-Tool BENCH_PERL @('perl')
    Erl    = Find-Tool BENCH_ERL @('erl')
    Swipl  = Find-Tool BENCH_SWIPL @('swipl')
    Octave = Find-Tool BENCH_OCTAVE @('octave-cli')
    Pure   = Find-Tool BENCH_PURE @('Pure', 'pure')
    Stew   = Find-Tool BENCH_STEW @('stew')
    # SteelPython, Methodox's Python 3.12 on .NET: spy.exe of its full distribution (the .NET runtime, as Divooka Compute ships it) and of its embedded one (Native AOT)
    Spy    = Find-Tool BENCH_SPY @('spy')
    SpyAot = Find-Tool BENCH_SPY_AOT @()
    Chrome = Find-Tool BENCH_CHROME @('chrome') (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe')
}
# Elixir runs on the Erlang runtime directly, as elixir.bat would start it, so the process measured is the one doing the work and not a batch file waiting for it.
$elixirRoot = if ($env:BENCH_ELIXIR) { $env:BENCH_ELIXIR } else { Get-Command elixir -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { Split-Path (Split-Path $_.Source) } }
$elixirPaths = @(if ($elixirRoot -and (Test-Path (Join-Path $elixirRoot 'lib'))) { Get-ChildItem (Join-Path $elixirRoot 'lib') -Directory | ForEach-Object { '-pa'; (Join-Path $_.FullName 'ebin') } })
#endregion

#region The programs
$scripts = if ($Benchmark -eq 'Mandelbrot') { Join-Path $root 'Scripts' } else { Join-Path $root 'RayTracer/Scripts' }
# File: what runs. Before: its arguments ahead of the work's (a script, a class path). Slow: SlowRounds rounds. Estimate: run at two smaller sizes instead of the full one. Page: a page Chrome runs.
$programs = if ($Benchmark -eq 'Mandelbrot')
{
    @(
        @{ Name = 'C++';                         File = "$build/C++/MandelbrotCPP.exe" }
        @{ Name = 'C#';                          File = "$build/C#/MandelbrotCSharp.exe" }
        @{ Name = 'C# AoT';                      File = "$build/C#AoT/MandelbrotCSharpAoT.exe"; Reference = $true }
        @{ Name = 'Go';                          File = "$build/Go/mandelbrot.exe" }
        @{ Name = 'Java';                        File = $tools.Java;   Before = @('-cp', "$build/Java", 'Mandelbrot') }
        @{ Name = 'Haskell';                     File = "$build/Haskell/mandelbrot.exe" }
        @{ Name = 'JavaScript (Node)';           File = $tools.Node;   Before = @("$scripts/JavaScript_Node/mandelbrot.js") }
        @{ Name = 'JavaScript (Web/Chrome)';     File = $tools.Chrome; Page = "$scripts/JavaScript_Web/mandelbrot.html" }
        @{ Name = 'Julia';                       File = $tools.Julia;  Before = @("$scripts/Julia/mandelbrot.jl") }
        @{ Name = 'Pure 2';                      File = $tools.Pure;   Before = @("$scripts/Pure2/mandelbrot.cs") }
        @{ Name = 'Divooka (stew, compiled)';    File = $tools.Stew;   Before = @("$scripts/Divooka/mandelbrot.dvk") }
        @{ Name = 'Divooka (AviatorBeta program)'; File = "$build/Divooka/MandelbrotDvk.exe" }
        @{ Name = 'Python';                      File = $tools.Python; Before = @("$scripts/Python/mandelbrotpython.py"); Slow = $true }
        @{ Name = 'SteelPython';                 File = $tools.Spy;    Before = @("$scripts/Python/mandelbrotpython.py"); Slow = $true }
        @{ Name = 'SteelPython (Native AOT)';    File = $tools.SpyAot; Before = @("$scripts/Python/mandelbrotpython.py"); Slow = $true }
        @{ Name = 'Ruby';                        File = $tools.Ruby;   Before = @("$scripts/Ruby/mandelbrot.ruby"); Slow = $true }
        @{ Name = 'Perl';                        File = $tools.Perl;   Before = @("$scripts/Perl/mandelbrot.pl"); Slow = $true }
        @{ Name = 'Elixir';                      File = $tools.Erl;    Before = $elixirPaths + @('-noshell', '-s', 'elixir', 'start_cli', '-extra', "$scripts/Elixir/mandelbrot.exs"); Slow = $true; Needs = $elixirPaths.Count }
        @{ Name = 'Prolog (SWI)';                File = $tools.Swipl;  Before = @('-q', "$scripts/Prolog/madelbrot.pl"); Slow = $true }
        @{ Name = 'GNU Octave';                  File = $tools.Octave; Before = @("$scripts/GNUOctave/mandelbrot.m"); Estimate = $true }
        @{ Name = 'Divooka (stew, interpreted)'; File = $tools.Stew;   Before = @('--mode', 'interpreted', "$scripts/Divooka/mandelbrot.dvk"); Estimate = $true }
    )
}
else
{
    @(
        @{ Name = 'C++';                         File = "$build/C++/RayTracerCPP.exe" }
        @{ Name = 'C#';                          File = "$build/C#/RayTracerCSharp.exe" }
        @{ Name = 'C# AoT';                      File = "$build/C#AoT/RayTracerCSharpAoT.exe"; Reference = $true }
        @{ Name = 'Go';                          File = "$build/Go/raytracer.exe" }
        @{ Name = 'Java';                        File = $tools.Java;   Before = @('-cp', "$build/Java", 'RayTracer') }
        @{ Name = 'Haskell';                     File = "$build/Haskell/raytracer.exe" }
        @{ Name = 'JavaScript (Node)';           File = $tools.Node;   Before = @("$scripts/JavaScript_Node/raytracer.js") }
        @{ Name = 'JavaScript (Web/Chrome)';     File = $tools.Chrome; Page = "$scripts/JavaScript_Web/raytracer.html" }
        @{ Name = 'Julia';                       File = $tools.Julia;  Before = @("$scripts/Julia/raytracer.jl") }
        @{ Name = 'Pure 2';                      File = $tools.Pure;   Before = @("$scripts/Pure2/raytracer.cs") }
        @{ Name = 'Divooka (stew, compiled)';    File = $tools.Stew;   Before = @("$scripts/Divooka/Ray Tracer.dvk") }
        @{ Name = 'Divooka (AviatorBeta program)'; File = "$build/Divooka/RayTracerDvk.exe" }
        @{ Name = 'Python';                      File = $tools.Python; Before = @("$scripts/Python/raytracer.py"); Slow = $true }
        @{ Name = 'SteelPython';                 File = $tools.Spy;    Before = @("$scripts/Python/raytracer.py"); Slow = $true }
        @{ Name = 'SteelPython (Native AOT)';    File = $tools.SpyAot; Before = @("$scripts/Python/raytracer.py"); Slow = $true }
        @{ Name = 'Ruby';                        File = $tools.Ruby;   Before = @("$scripts/Ruby/raytracer.rb"); Slow = $true }
        @{ Name = 'Perl';                        File = $tools.Perl;   Before = @("$scripts/Perl/raytracer.pl"); Slow = $true }
        @{ Name = 'Elixir';                      File = $tools.Erl;    Before = $elixirPaths + @('-noshell', '-s', 'elixir', 'start_cli', '-extra', "$scripts/Elixir/raytracer.exs"); Slow = $true; Needs = $elixirPaths.Count }
        @{ Name = 'Prolog (SWI)';                File = $tools.Swipl;  Before = @('-q', "$scripts/Prolog/raytracer.pl"); Slow = $true }
        @{ Name = 'GNU Octave';                  File = $tools.Octave; Before = @("$scripts/GNUOctave/raytracer.m"); Estimate = $true }
        @{ Name = 'Divooka (stew, interpreted)'; File = $tools.Stew;   Before = @('--mode', 'interpreted', "$scripts/Divooka/Ray Tracer.dvk"); Estimate = $true }
    )
}
function Test-Name([string] $name, [string[]] $patterns) { foreach ($pattern in $patterns) { if ($name -like $pattern) { return $true } }; return $false }
$programs = @($programs | Where-Object { ($_.Reference -or -not $Only -or (Test-Name $_.Name $Only)) -and -not (Test-Name $_.Name $Skip) })
$reference = $programs | Where-Object { $_.Reference } | Select-Object -First 1
if (-not $reference -or -not (Test-Path $reference.File)) { throw 'The reference program (C# AoT) is not built: run Benchmark/Build.ps1 first.' }
$runnable = @(foreach ($program in $programs)
{
    if (-not $program.File -or -not (Test-Path $program.File) -or ($program.ContainsKey('Needs') -and -not $program.Needs)) { Write-Warning "$($program.Name): not found, skipped."; continue }
    if ($Only -and $program.Reference -and -not (Test-Name $program.Name $Only)) { continue }
    $program
})
#endregion

#region The work
# A size is what one run is asked to do, and how much work that is: a Mandelbrot run's iterations, which its checksum counts, or the ray tracer's primary rays.
if ($Benchmark -eq 'Mandelbrot')
{
    $full = @{ Label = '2000x2000x1000'; Arguments = @('2000', '2000', '1000') }
    $smaller = @(@{ Label = '100x100x1000'; Arguments = @('100', '100', '1000') }, @{ Label = '200x200x1000'; Arguments = @('200', '200', '1000') })
}
else
{
    $sceneText = Get-Content (Join-Path $root 'RayTracer/scene.txt')
    function Write-Scene([string] $label, [int] $width, [int] $height, [int] $samples)
    {
        $path = Join-Path $work "scene-$label.txt"
        $sceneText | ForEach-Object { if ($_ -match '^\s*size\b') { "size $width $height" } elseif ($_ -match '^\s*samples\b') { "samples $samples" } else { $_ } } | Set-Content -Encoding ascii $path
        return $path
    }
    $size = @(($sceneText | Where-Object { $_ -match '^\s*size\b' } | Select-Object -First 1) -split '\s+' | Where-Object { $_ })
    $samples = @(($sceneText | Where-Object { $_ -match '^\s*samples\b' } | Select-Object -First 1) -split '\s+' | Where-Object { $_ })
    $full = @{ Label = 'scene.txt'; Scene = (Join-Path $root 'RayTracer/scene.txt'); Rays = [int]$size[1] * [int]$size[2] * [int]$samples[1] * [int]$samples[1] }
    $smaller = @(
        @{ Label = '80x60'; Scene = (Write-Scene '80x60' 80 60 1); Rays = 80 * 60 }
        @{ Label = '160x120'; Scene = (Write-Scene '160x120' 160 120 1); Rays = 160 * 120 }
    )
}
#endregion

#region One run
$timeout = $TimeoutMinutes * 60 * 1000
function Invoke-Program($program, $size)
{
    if ($program.Page)
    {
        # The page times its own render, after a warm-up, and prints its answer into the document Chrome dumps.
        $query = if ($Benchmark -eq 'Mandelbrot') { "?w=$($size.Arguments[0])&h=$($size.Arguments[1])&i=$($size.Arguments[2])" } else { '' }
        $page = ([Uri](Resolve-Path $program.Page).Path).AbsoluteUri + $query
        $outcome = [BenchmarkProcess]::Run($program.File, [string[]]@('--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', "--user-data-dir=$(Join-Path $work 'chrome-profile')", '--virtual-time-budget=600000', '--dump-dom', $page), $work, $timeout)
        $text = $outcome.Output -replace '<[^>]+>', "`n"
        $inPage = if ($text -match 'time_ms=([\d.]+)') { [double]$Matches[1] } elseif ($text -match 'Render: ([\d.]+) ms') { [double]$Matches[1] } else { $null }
        return [pscustomobject]@{ Outcome = $outcome; Text = $text; Milliseconds = $inPage; Picture = $null; PeakMB = $null }
    }
    # A program with nothing ahead of the work has no Before at all, and @($null) would be one empty argument.
    $arguments = @(if ($program.Before) { $program.Before })
    $picture = $null
    if ($Benchmark -eq 'Mandelbrot') { $arguments += $size.Arguments }
    else
    {
        $picture = Join-Path $work ('{0}-{1}.ppm' -f ($program.Name -replace '[^\w]+', '_'), $size.Label)
        Remove-Item -ErrorAction SilentlyContinue $picture
        $arguments += @($size.Scene, $picture)
    }
    $outcome = [BenchmarkProcess]::Run($program.File, [string[]]$arguments, $work, $timeout)
    return [pscustomobject]@{ Outcome = $outcome; Text = $outcome.Output; Milliseconds = $outcome.Milliseconds; Picture = $picture; PeakMB = $outcome.PeakWorkingSetMB }
}
# The answer a run gave: the checksum it printed, and for the ray tracer the SHA-256 of the picture it wrote (the page prints its own).
function Read-Answer($run)
{
    $checksum = if ($run.Text -match 'Checksum: (\d+)') { $Matches[1] } elseif ($run.Text -match 'checksum=(\d+)') { $Matches[1] } elseif ($run.Text -match '(?m)^\s*(\d+)\s*$') { $Matches[1] } else { $null }
    $digest = $null
    if ($run.Picture -and (Test-Path $run.Picture)) { $digest = (Get-FileHash -Algorithm SHA256 $run.Picture).Hash.ToLowerInvariant(); Remove-Item $run.Picture }
    elseif ($run.Text -match 'PPM SHA-256: ([0-9a-f]{64})') { $digest = $Matches[1] }
    return [pscustomobject]@{ Checksum = $checksum; Digest = $digest }
}
function Get-Load
{
    try { [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 | ForEach-Object { $_.CounterSamples.CookedValue } | Measure-Object -Average).Average, 1) } catch { $null }
}
#endregion

#region The reference answers
$sizes = @($full) + $smaller
$expected = @{}
foreach ($size in $sizes)
{
    $run = Invoke-Program $reference $size
    $answer = Read-Answer $run
    if ($run.Outcome.ExitCode -ne 0 -or -not $answer.Checksum) { throw "The reference failed at $($size.Label): $($run.Outcome.Error)" }
    $expected[$size.Label] = $answer
    Write-Host ('Reference at {0}: checksum {1}{2}' -f $size.Label, $answer.Checksum, $(if ($answer.Digest) { ", SHA-256 $($answer.Digest)" }))
}
function Test-Answer($size, $answer)
{
    $want = $expected[$size.Label]
    return $answer.Checksum -eq $want.Checksum -and ($Benchmark -eq 'Mandelbrot' -or $answer.Digest -eq $want.Digest)
}
#endregion

#region Rounds
$machine = [pscustomobject]@{
    CPU = (Get-CimInstance Win32_Processor).Name; Cores = (Get-CimInstance Win32_Processor).NumberOfCores; Threads = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    RAM_GB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2); OS = (Get-CimInstance Win32_OperatingSystem).Caption; OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
}
$machine | Format-List | Out-String | Write-Host
$rows = [System.Collections.Generic.List[object]]::new()
$loads = [System.Collections.Generic.List[double]]::new()
$most = [math]::Max($Rounds, $SlowRounds)
for ($round = 1; $round -le $most; $round++)
{
    $load = Get-Load
    if ($null -ne $load) { $loads.Add($load) }
    Write-Host "Round $round (processor load before it: $load%)"
    # Each round starts one program further along, so no program always runs first or always follows the same one.
    $order = for ($index = 0; $index -lt $runnable.Count; $index++) { $runnable[($index + $round - 1) % $runnable.Count] }
    foreach ($program in $order)
    {
        $wanted = if ($program.Slow -or $program.Estimate) { $SlowRounds } else { $Rounds }
        if ($round -gt $wanted) { continue }
        $runSizes = if ($program.Estimate) { $smaller } else { @($full) }
        foreach ($size in $runSizes)
        {
            $run = Invoke-Program $program $size
            $answer = Read-Answer $run
            $right = $run.Outcome.ExitCode -eq 0 -and -not $run.Outcome.TimedOut -and (Test-Answer $size $answer)
            $row = [pscustomobject]@{
                Name = $program.Name; Size = $size.Label; Round = $round; Right = $right; ExitCode = $run.Outcome.ExitCode
                TimeMs = if ($null -ne $run.Milliseconds) { [math]::Round($run.Milliseconds, 2) } else { $null }
                PeakMemoryMB = if ($null -ne $run.PeakMB) { [math]::Round($run.PeakMB, 2) } else { $null }
                Checksum = $answer.Checksum; Load = $load
            }
            $rows.Add($row)
            $said = if ($right) { 'right' } else { "WRONG (exit $($row.ExitCode), checksum $($answer.Checksum)) $(($run.Outcome.Error -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1))" }
            Write-Host ('  {0,-30} {1,-14} {2,12} ms {3,10} MB {4}' -f $program.Name, $size.Label, $row.TimeMs, $row.PeakMemoryMB, $said)
        }
    }
}
$rows | Export-Csv -NoTypeInformation (Join-Path $work 'runs.csv')
#endregion

#region Summary
function Get-Median([double[]] $values) { $sorted = @($values | Sort-Object); $n = $sorted.Count; if ($n -eq 0) { return $null }; if ($n % 2) { return $sorted[($n - 1) / 2] }; return ($sorted[$n / 2 - 1] + $sorted[$n / 2]) / 2 }
function Get-Work($size) { if ($Benchmark -eq 'Mandelbrot') { [double]$expected[$size.Label].Checksum } else { [double]$size.Rays } }
$summary = foreach ($program in $runnable)
{
    $mine = @($rows | Where-Object { $_.Name -eq $program.Name })
    $wrong = @($mine | Where-Object { -not $_.Right }).Count
    $good = @($mine | Where-Object { $_.Right })
    $memory = @($good | Where-Object { $null -ne $_.PeakMemoryMB } | ForEach-Object PeakMemoryMB)
    $peak = if ($memory.Count) { [math]::Round((Get-Median $memory), 2) } else { $null }
    if ($program.Estimate)
    {
        $first = @($good | Where-Object { $_.Size -eq $smaller[0].Label } | ForEach-Object TimeMs)
        $second = @($good | Where-Object { $_.Size -eq $smaller[1].Label } | ForEach-Object TimeMs)
        if ($first.Count -eq 0 -or $second.Count -eq 0) { [pscustomobject]@{ Name = $program.Name; Runs = $good.Count; Wrong = $wrong; MedianMs = $null; RangeMs = 'no right runs'; PeakMemoryMB = $null; Note = 'estimate' }; continue }
        $m1 = Get-Median $first; $m2 = Get-Median $second
        $w1 = Get-Work $smaller[0]; $w2 = Get-Work $smaller[1]; $wf = Get-Work $full
        $estimate = $m1 + ($m2 - $m1) * ($wf - $w1) / ($w2 - $w1)
        $largerMemory = @($good | Where-Object { $_.Size -eq $smaller[1].Label -and $null -ne $_.PeakMemoryMB } | ForEach-Object PeakMemoryMB)
        $largerPeak = if ($largerMemory.Count) { [math]::Round((Get-Median $largerMemory), 2) } else { $null }
        [pscustomobject]@{ Name = $program.Name; Runs = $good.Count; Wrong = $wrong; MedianMs = [math]::Round($estimate, 0); RangeMs = ('estimate, from medians {0:N0} ms at {1} and {2:N0} ms at {3}' -f $m1, $smaller[0].Label, $m2, $smaller[1].Label); PeakMemoryMB = $largerPeak; Note = "estimate; memory at $($smaller[1].Label)" }
        continue
    }
    $times = @($good | ForEach-Object TimeMs)
    [pscustomobject]@{
        Name = $program.Name; Runs = $good.Count; Wrong = $wrong
        MedianMs = if ($times.Count) { [math]::Round((Get-Median $times), 2) } else { $null }
        RangeMs = if ($times.Count) { '{0:N2} - {1:N2}' -f ($times | Measure-Object -Minimum).Minimum, ($times | Measure-Object -Maximum).Maximum } else { 'no right runs' }
        PeakMemoryMB = $peak
        Note = if ($program.Page) { 'in page, render only' } else { '' }
    }
}
$summary = @($summary | Sort-Object { if ($null -eq $_.MedianMs) { [double]::MaxValue } else { [double]$_.MedianMs } })
$medianLoad = Get-Median @($loads)
$lines = @(
    "Benchmark: $Benchmark ($($full.Label)); rounds: $Rounds (slow programs and estimates: $SlowRounds); processor load before each round: median $medianLoad% (range $(($loads | Measure-Object -Minimum).Minimum)% - $(($loads | Measure-Object -Maximum).Maximum)%)"
    ''
    '|Program|Median (ms)|Range (ms)|Peak memory (MB)|Runs|Wrong|Note|'
    '|-|-:|-|-:|-:|-:|-|'
) + @($summary | ForEach-Object { '|{0}|{1}|{2}|{3}|{4}|{5}|{6}|' -f $_.Name, $(if ($null -ne $_.MedianMs) { '{0:N2}' -f $_.MedianMs }), $_.RangeMs, $(if ($null -ne $_.PeakMemoryMB) { '{0:N2}' -f $_.PeakMemoryMB } else { 'N/A' }), $_.Runs, $_.Wrong, $_.Note })
$lines | Set-Content -Encoding utf8 (Join-Path $work 'summary.md')
$lines | Write-Host
Write-Host "Runs and summary: $work"
#endregion
