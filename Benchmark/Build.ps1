<#
.SYNOPSIS
Builds every benchmark program that has to be compiled before it runs, into Artifacts/Build.

.DESCRIPTION
C++ (MSBuild, Release x64), C# (self-contained, single file, trimmed), C# AoT (NativeAOT), Go, Java and Haskell, for both benchmarks, and each Divooka document built into a program of its own when AviatorBeta is named. The interpreted languages need nothing built, and stew runs the Divooka documents as they are.

Artifacts/Build is ignored by git; this script is how it is filled. Benchmark.ps1 runs what it builds.

Toolchains, each found the usual way:
- C++: Visual Studio 2022 or later with the desktop C++ workload, found with vswhere.
- C# and C# AoT: the .NET 10 SDK on PATH; NativeAOT also needs the Visual Studio C++ tools, which it finds through vswhere.
- Go: go on PATH. Built for GOAMD64=v1, the default, so the compiler never fuses a multiply and an add into one instruction - a fused one rounds once instead of twice, and the ray tracer's pictures would no longer be the same to the byte.
- Java: the JDK at JAVA_HOME, else javac on PATH. Java 17 or later, whose floating point is strict by definition.
- Haskell: ghc on PATH (GHCup installs one).
- Divooka: the AviatorBeta.exe of a Divooka Compute folder, named by BENCH_AVIATOR, builds each Divooka document into a program of its own, as Divooka Compute's Publish does. Skipped when BENCH_AVIATOR is not set; stew runs the documents either way.

.PARAMETER Only
Build only these languages (C++, C#, C# AoT, Go, Java, Haskell, Divooka).

.EXAMPLE
pwsh Benchmark/Build.ps1
#>
param(
    [string[]] $Only
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'Artifacts/Build'

function Wanted([string] $language) { -not $Only -or $Only -contains $language }
function Invoke-Checked([string] $what, [scriptblock] $command)
{
    Write-Host "Building $what"
    & $command
    if ($LASTEXITCODE -ne 0) { throw "Building $what failed (exit code $LASTEXITCODE)." }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
# NativeAOT looks for the linker through vswhere, which it expects on PATH.
if (Test-Path $vswhere) { $env:PATH = (Split-Path $vswhere) + ';' + $env:PATH }
$javac = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\javac.exe' } else { 'javac' }

# Each benchmark's sources: the Mandelbrot benchmark's under Scripts, the ray tracer's under RayTracer/Scripts.
$benchmarks = @(
    @{ Name = 'Mandelbrot'; Scripts = Join-Path $root 'Scripts'
       Cpp = 'C++/MandelbrotCPP/MandelbrotCPP/MandelbrotCPP.vcxproj'; CSharp = 'C#/MandelbrotCSharp/MandelbrotCSharp/MandelbrotCSharp.csproj'; CSharpAoT = 'C#AoT/MandelbrotCSharpAoT/MandelbrotCSharpAoT/MandelbrotCSharpAoT.csproj'
       Go = 'Go/mandelbrot.go'; Java = 'Java/Mandelbrot.java'; Haskell = 'Haskell/mandelbrot.hs'; Divooka = 'Divooka/mandelbrot.dvk'; DivookaProgram = 'MandelbrotDvk' }
    @{ Name = 'RayTracer'; Scripts = Join-Path $root 'RayTracer/Scripts'
       Cpp = 'C++/RayTracerCPP/RayTracerCPP/RayTracerCPP.vcxproj'; CSharp = 'C#/RayTracerCSharp/RayTracerCSharp.csproj'; CSharpAoT = 'C#AoT/RayTracerCSharpAoT/RayTracerCSharpAoT.csproj'
       Go = 'Go/raytracer.go'; Java = 'Java/RayTracer.java'; Haskell = 'Haskell/raytracer.hs'; Divooka = 'Divooka/Ray Tracer.dvk'; DivookaProgram = 'RayTracerDvk' }
)

foreach ($benchmark in $benchmarks)
{
    $scripts = $benchmark.Scripts
    $out = Join-Path $build $benchmark.Name
    $obj = Join-Path $build "obj/$($benchmark.Name)"

    if (Wanted 'C++')
    {
        $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
        if (-not $msbuild) { throw 'MSBuild was not found: install Visual Studio with the desktop C++ workload.' }
        Invoke-Checked "$($benchmark.Name) C++" { & $msbuild (Join-Path $scripts $benchmark.Cpp) /nologo /v:minimal /p:Configuration=Release /p:Platform=x64 "/p:OutDir=$(Join-Path $out 'C++')\" "/p:IntDir=$(Join-Path $obj 'C++')\" }
    }
    if (Wanted 'C#')
    {
        Invoke-Checked "$($benchmark.Name) C#" { dotnet publish (Join-Path $scripts $benchmark.CSharp) -nologo -v q -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=true -o (Join-Path $out 'C#') }
    }
    if (Wanted 'C# AoT')
    {
        Invoke-Checked "$($benchmark.Name) C# AoT" { dotnet publish (Join-Path $scripts $benchmark.CSharpAoT) -nologo -v q -c Release -r win-x64 -o (Join-Path $out 'C#AoT') }
    }
    if (Wanted 'Go')
    {
        $previous = $env:GOAMD64
        $env:GOAMD64 = 'v1'
        try
        {
            $source = Join-Path $scripts $benchmark.Go
            Invoke-Checked "$($benchmark.Name) Go" { go build -o (Join-Path $out "Go/$([IO.Path]::GetFileNameWithoutExtension($source)).exe") $source }
        }
        finally { $env:GOAMD64 = $previous }
    }
    if (Wanted 'Java')
    {
        Invoke-Checked "$($benchmark.Name) Java" { & $javac -d (Join-Path $out 'Java') (Join-Path $scripts $benchmark.Java) }
    }
    if (Wanted 'Haskell')
    {
        $source = Join-Path $scripts $benchmark.Haskell
        New-Item -ItemType Directory -Force (Join-Path $out 'Haskell') | Out-Null
        Invoke-Checked "$($benchmark.Name) Haskell" { ghc -O2 -v0 -outputdir (Join-Path $obj 'Haskell') -o (Join-Path $out "Haskell/$([IO.Path]::GetFileNameWithoutExtension($source)).exe") $source }
    }
    # The Divooka document built into a program of its own by AviatorBeta, which Divooka Compute's Publish runs: only when BENCH_AVIATOR names the AviatorBeta.exe of a Divooka Compute folder.
    if ((Wanted 'Divooka') -and $env:BENCH_AVIATOR)
    {
        $document = Join-Path $scripts $benchmark.Divooka
        Invoke-Checked "$($benchmark.Name) Divooka" { & $env:BENCH_AVIATOR build $document (Join-Path $out 'Divooka') --name $benchmark.DivookaProgram }
    }
}
Write-Host "Built into $build"
