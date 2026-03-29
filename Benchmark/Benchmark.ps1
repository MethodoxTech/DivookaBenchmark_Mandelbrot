$runs = 5

$tests = @(
    @{ Name = "C++"; FilePath = "../Artifacts/Win64/MangelbrotCPP.exe"; Arguments = "" }
    @{ Name = "C# Trimmed"; FilePath = "../Artifacts/Win64/MandelbrotCSharp.exe"; Arguments = "" }
    @{ Name = "C# AoT"; FilePath = "../Artifacts/Win64/MandelbrotCSharpAoT.exe"; Arguments = "" }
    @{ Name = "Python"; FilePath = "python"; Arguments = "../Scripts/Python/mandelbrotpython.py" }
)

$results = foreach ($test in $tests) {
    Write-Host $test
    foreach ($i in 1..$runs) {
        Write-Host $i

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $p = Start-Process -FilePath $test.FilePath `
                           -ArgumentList $test.Arguments `
                           -PassThru `
                           -NoNewWindow `
                           -Wait

        $sw.Stop()
        $p.Refresh()

        [pscustomobject]@{
            Name         = $test.Name
            Run          = $i
            ExitCode     = $p.ExitCode
            TimeMs       = $sw.Elapsed.TotalMilliseconds
            PeakMemoryMB = [math]::Round($p.PeakWorkingSet64 / 1MB, 2)
        }
    }
}

$results | Format-Table -AutoSize

Write-Host "Summary:"

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
        }
    } |
    Sort-Object AvgTimeMs |
    Format-Table -AutoSize