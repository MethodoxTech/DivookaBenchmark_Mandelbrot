# DivookaBenchmark_Mandelbrot

A benchmark for Divooka.

## Experiment Set

default 2000 x 2000, maxIter = 1000, runs = 5

|Platform|Peak Memory (Mb)|Run Time (s)|
|-|-|-|
|C++|||
|C# (.Net 10)|||
|C# AoT|||
|Python (3.13.5)|||
|Divooka|||

## Records

### 20260328

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

## Limitations

* There are a few loops but no recursion or deep function calls.