[pscustomobject]@{
    CPU        = (Get-CimInstance Win32_Processor).Name
    Cores      = (Get-CimInstance Win32_Processor).NumberOfCores
    Threads    = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    RAM_GB     = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    GPU        = (Get-CimInstance Win32_VideoController).Name -join "; "
    OS         = (Get-CimInstance Win32_OperatingSystem).Caption
    OSVersion  = (Get-CimInstance Win32_OperatingSystem).Version
} | Format-List

$runs = 5

$tests = @(
    @{ Name = "JS (Node)";          FilePath = "node";                                         Arguments = @("../Scripts/JavaScript_Node/mandelbrot.js") }
    @{ Name = "C++";                FilePath = "../Artifacts/Win64/MandelbrotCPP.exe";         Arguments = @() }
    @{ Name = "Go";                 FilePath = "go";                                           Arguments = @("run", "../Scripts/Go/mandelbrot.go") }
    @{ Name = "C# AoT";             FilePath = "../Artifacts/Win64/MandelbrotCSharpAoT.exe";   Arguments = @() }
    @{ Name = "C# Trimmed";         FilePath = "../Artifacts/Win64/MandelbrotCSharp.exe";      Arguments = @() }
    @{ Name = "Java";               FilePath = "java";                                         Arguments = @("-cp", "../Scripts/Java", "Mandelbrot") }
    @{ Name = "Ruby";               FilePath = "ruby";                                         Arguments = @("../Scripts/Ruby/mandelbrot.ruby") }
    @{ Name = "Python";             FilePath = "python";                                       Arguments = @("../Scripts/Python/mandelbrotpython.py") }
    @{ Name = "Prolog (SWI)";       FilePath = "swipl";                                        Arguments = @("-q", "-f", "../Scripts/Prolog/madelbrot.pl") }
    @{ Name = "GNU Octave";         FilePath = "octave.exe";                                   Arguments = @("../Scripts/GNUOctave/mandelbrot.m") }
    @{ Name = "Julia";              FilePath = "julia";                                        Arguments = @("../Scripts/Julia/mandelbrot.jl", "2000", "2000", "1000") }
    @{ Name = "Divooka (Aviator)";  FilePath = "Aviator";                                      Arguments = @("run", "../Scripts/Divooka/mandelbrot.dvk") }
    @{ Name = "Divooka (Compiled)"; FilePath = "../Artifacts/Win64/MandelbrotDvk.exe";         Arguments = @() }
    @{ Name = "Divooka (Stewer)";   FilePath = "stew";                                         Arguments = @("../Scripts/Divooka/mandelbrot.dvk") }
)

$results = foreach ($test in $tests) {
    Write-Host "Running $($test.Name)"

    foreach ($i in 1..$runs) {
        Write-Host "  Run $i"

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $p = Start-Process `
            -FilePath $test.FilePath `
            -ArgumentList $test.Arguments `
            -PassThru `
            -NoNewWindow

        $peakWorkingSet = 0

        while (-not $p.HasExited) {
            try {
                $p.Refresh()
                if ($p.WorkingSet64 -gt $peakWorkingSet) {
                    $peakWorkingSet = $p.WorkingSet64
                }
            }
            catch {
                break
            }

            Start-Sleep -Milliseconds 10
        }

        $p.WaitForExit()
        $sw.Stop()

        [pscustomobject]@{
            Name         = $test.Name
            Run          = $i
            ExitCode     = $p.ExitCode
            TimeMs       = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            PeakMemoryMB = [math]::Round($peakWorkingSet / 1MB, 2)
            PeakMemoryKB = [math]::Round($peakWorkingSet / 1KB, 2)
        }
    }
}

$results | Format-Table -AutoSize

Write-Host "`nSummary:"

$results |
    Group-Object Name |
    ForEach-Object {
        $rows = $_.Group
        [pscustomobject]@{
            Name            = $_.Name
            Runs            = $rows.Count
            AvgTimeMs       = [math]::Round(($rows | Measure-Object TimeMs -Average).Average, 2)
            MinTimeMs       = [math]::Round(($rows | Measure-Object TimeMs -Minimum).Minimum, 2)
            MaxTimeMs       = [math]::Round(($rows | Measure-Object TimeMs -Maximum).Maximum, 2)
            AvgPeakMemoryMB = [math]::Round(($rows | Measure-Object PeakMemoryMB -Average).Average, 2)
            MaxPeakMemoryMB = [math]::Round(($rows | Measure-Object PeakMemoryMB -Maximum).Maximum, 2)
            AvgPeakMemoryKB = [math]::Round(($rows | Measure-Object PeakMemoryKB -Average).Average, 2)
            MaxPeakMemoryKB = [math]::Round(($rows | Measure-Object PeakMemoryKB -Maximum).Maximum, 2)
        }
    } |
    Sort-Object AvgTimeMs |
    Format-Table -AutoSize