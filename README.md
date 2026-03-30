# DivookaBenchmark_Mandelbrot

A benchmark for Divooka.

## Experiment Set

**Setup**

Mandelbrot:

* Default 2000 x 2000, MaxIter = 1000, Runs = 5 (Correct output: 689833081)
* Exercises integer math, floating point, loops, branches, function calls, and memory writes
* Compare the printed checksum matches across all implementations

**Best Results**

* Size refer to default distribution, which can typically be further optimized (e.g. embedded python, Divooka™ Compute)

|Rank (by Time)|Platform|Size|Run Time (Ms)|Peak Memory|
|-|-|-|-|-|
|1|JavaScript (Web/MS Edge)|3 Kb|1295.80 (No startup time)|≈9.54 MB|
|1|JavaScript (Web/Chrome)|3 Kb|1298.70 (No startup time)|≈9.54 MB|
|1|JavaScript (Web/Brave)|3 Kb|1302.80 (No startup time)|≈9.54 MB|
|2|C++|15 Kb|1308|18.62 Mb|
|3|C# AoT|911 Kb|1355.35|17.98 Mb|
|4|C# (.Net 10)|16.5 Mb|1357.47|26.88 Mb|
|5|JavaScript (Node)|2 Kb + 98.2 Mb|1406.20|49.47 Mb|
|6|Go|2 Kb + 224 Mb|1425|20.79 Mb|
|7|JavaScript (Web/Firefox)|3 Kb|1513.00|N/A|
|8|Java (OpenJDK) (17.0.11)|2 Kb + 2 Kb + 301 Mb|1587.79|55.2 Mb|
|9|Python (3.13.5)|2 Kb + 139 Mb|47127|61.4 Mb|
|10|Ruby (3.2.2)|1 Kb + 907 Mb|49489|52.45 Mb|
|11|Prolog (SWI) (With optimization)|2 Kb + 42.8 Mb|314687|12.67 Mb|
|12|GNU Octave (7.3.0)|2 Kb + 2.07 Gb|2464913 (41 min)|5.46Mb|
|N/A|Haskell||||
|N/A|Julia||||
|N/A|Perl||||
|N/A|Elixir||||
|N/A|Pure 2||||
|N/A|Divooka (0.75.2)||||

**Observations**

* Damn JavaScript is fast.
* Python is surprisingly slow.
* GNU Octave is surprisingly slow.
* JavaScript is surprisingly fast.
* I know Octave is probably optimized for matrix operations - but raw iteration speed is 💩.
* Ruby.. oh my Ruby...
* GNU Octave seems very naive interpretation (but ues very little memory)?
* Modern scripting languages are not usable without JIT.

## Records

### 20260328

```
CPU       : 13th Gen Intel(R) Core(TM) i7-13700KF
Cores     : 16
Threads   : 24
RAM_GB    : 127.84
GPU       : NVIDIA GeForce RTX 4090
OS        : Microsoft Windows 11 Pro
OSVersion : 10.0.22631
```

**Run 1**

```
Name       Run ExitCode   TimeMs PeakMemoryMB
----       --- --------   ------ ------------
C++          1        0  2466.36         0.00
C++          2        0  2016.02         0.00
C++          3        0  2005.51         0.00
C++          4        0  2008.23         0.00
C++          5        0  2010.93         0.00
C# Trimmed   1        0  2113.89         0.00
C# Trimmed   2        0  2007.61         0.00
C# Trimmed   3        0  2008.79         0.00
C# Trimmed   4        0  2002.98         0.00
C# Trimmed   5        0  2005.13         0.00
C# AoT       1        0  2047.63         0.00
C# AoT       2        0  2015.38         0.00
C# AoT       3        0  2013.55         0.00
C# AoT       4        0  2005.27         0.00
C# AoT       5        0  2015.76         0.00
Python       1        0 53020.98         0.00
Python       2        0 51016.43         0.00
Python       3        0 48010.12         0.00
Python       4        0 48008.35         0.00
Python       5        0 53017.28         0.00

Summary:

Name       Runs AvgTimeMs MinTimeMs MaxTimeMs AvgPeakMemoryMB MaxPeakMemoryMB
----       ---- --------- --------- --------- --------------- ---------------
C# AoT        5   2019.52   2005.27   2047.63            0.00            0.00
C# Trimmed    5   2027.68   2002.98   2113.89            0.00            0.00
C++           5   2101.41   2005.51   2466.36            0.00            0.00
Python        5  50614.63  48008.35  53020.98            0.00            0.00
```

**Run 2**

```
Name       Run ExitCode   TimeMs PeakMemoryMB PeakMemoryKB
----       --- --------   ------ ------------ ------------
C++          1        0  1329.55        18.88     19336.00
C++          2        0  1323.36        18.57     19012.00
C++          3        0  1314.83        18.56     19004.00
C++          4        0  1332.19        18.56     19004.00
C++          5        0  1308.00        18.55     19000.00
C# Trimmed   1        0  1365.41        29.60     30308.00
C# Trimmed   2        0  1360.31        29.11     29804.00
C# Trimmed   3        0  1357.47        25.53     26140.00
C# Trimmed   4        0  1382.25        24.84     25440.00
C# Trimmed   5        0  1367.06        25.32     25932.00
C# AoT       1        0  1386.98        17.80     18232.00
C# AoT       2        0  1366.62        17.93     18356.00
C# AoT       3        0  1355.35        18.74     19192.00
C# AoT       4        0  1374.50        17.34     17756.00
C# AoT       5        0  1355.38        17.96     18388.00
Python       1        0 57932.10        61.42     62892.00
Python       2        0 53340.35        61.42     62896.00
Python       3        0 47127.70        61.39     62868.00
Python       4        0 47748.71        61.40     62876.00
Python       5        0 47256.38        61.39     62868.00


Summary:

Name       Runs AvgTimeMs MinTimeMs MaxTimeMs AvgPeakMemoryMB MaxPeakMemoryMB AvgPeakMemoryKB MaxPeakMemoryKB
----       ---- --------- --------- --------- --------------- --------------- --------------- ---------------
C++           5   1321.59   1308.00   1332.19           18.62           18.88        19071.20        19336.00
C# Trimmed    5   1366.50   1357.47   1382.25           26.88           29.60        27524.80        30308.00
C# AoT        5   1367.77   1355.35   1386.98           17.95           18.74        18384.80        19192.00
Python        5  50681.05  47127.70  57932.10           61.40           61.42        62880.00        62896.00
```

## 20260329

```
Name       Run ExitCode  TimeMs PeakMemoryMB PeakMemoryKB
----       --- --------  ------ ------------ ------------
Java         1        0 2172.38        54.81     56124.00
Java         2        0 1587.79        55.12     56444.00
Java         3        0 2170.23        54.94     56260.00
Java         4        0 2180.13        55.20     56520.00
Java         5        0 2161.38        54.95     56268.00
JS (Node)    1        0 1414.63        48.76     49932.00
JS (Node)    2        0 1408.87        50.67     51884.00
JS (Node)    3        0 1416.41        48.07     49224.00
JS (Node)    4        0 1421.06        49.81     51008.00
JS (Node)    5        0 1406.20        50.05     51248.00


Summary:

Name       Runs AvgTimeMs MinTimeMs MaxTimeMs AvgPeakMemoryMB MaxPeakMemoryMB AvgPeakMemoryKB MaxPeakMemoryKB
----       ---- --------- --------- --------- --------------- --------------- --------------- ---------------
JS (Node)     5   1413.43   1406.20   1421.06           49.47           50.67        50659.20        51884.00
Java          5   2054.38   1587.79   2180.13           55.00           55.20        56323.20        56520.00
```

```
Name         Run ExitCode    TimeMs PeakMemoryMB PeakMemoryKB
----         --- --------    ------ ------------ ------------
Go             1        0   1524.35        20.63     21124.00
Go             2        0   1430.81        21.00     21500.00
Go             3        0   1570.79        21.45     21960.00
Go             4        0   1437.50        20.39     20884.00
Go             5        0   1425.01        20.47     20960.00
Ruby           1        0  49693.17        52.45     53712.00
Ruby           2        0  49644.62        52.49     53748.00
Ruby           3        0  49489.82        52.48     53740.00
Ruby           4        0  49720.23        52.38     53636.00
Ruby           5        0  49634.29        52.44     53696.00
Prolog (SWI)   1        0 314687.84        12.66     12960.00
Prolog (SWI)   2        0 317327.18        12.68     12984.00
Prolog (SWI)   3        0 336952.45        12.66     12964.00
Prolog (SWI)   4        0 314983.90        12.67     12972.00
Prolog (SWI)   5        0 338078.59        12.68     12984.00


Summary:

Name         Runs AvgTimeMs MinTimeMs MaxTimeMs AvgPeakMemoryMB MaxPeakMemoryMB AvgPeakMemoryKB MaxPeakMemoryKB
----         ---- --------- --------- --------- --------------- --------------- --------------- ---------------
Go              5   1477.69   1425.01   1570.79           20.79           21.45        21285.60        21960.00
Ruby            5  49636.43  49489.82  49720.23           52.45           52.49        53706.40        53748.00
Prolog (SWI)    5 324405.99 314687.84 338078.59           12.67           12.68        12972.80        12984.00
```

## 20260330

```
Name       Run ExitCode     TimeMs PeakMemoryMB PeakMemoryKB
----       --- --------     ------ ------------ ------------
GNU Octave   1        0 2485694.66         5.50      5628.00
GNU Octave   2        0 2464913.29         5.45      5580.00
GNU Octave   3        0 2483131.48         5.45      5580.00
GNU Octave   4        0 2468400.16         5.44      5572.00
GNU Octave   5        0 2474652.51         5.45      5584.00


Summary:

Name       Runs  AvgTimeMs  MinTimeMs  MaxTimeMs AvgPeakMemoryMB MaxPeakMemoryMB AvgPeakMemoryKB MaxPeakMemoryKB
----       ----  ---------  ---------  --------- --------------- --------------- --------------- ---------------
GNU Octave    5 2475358.42 2464913.29 2485694.66            5.46            5.50         5588.80         5628.00
```

## Limitations

The benchmark only tests simple loops and large integers:

* Other programs do not have special warm-up handling so JavaScript (web) has an advantage.
* There are a few loops but no recursion or deep function calls - Divooka may suffer when call hierarchy is deep.
* This tests raw native run time speed, but different programming systems have different uses - e.g. people rarely use Python as is.
* Certain languages are more suited for certain things. GNU Octave is supposedly very good at matrix.