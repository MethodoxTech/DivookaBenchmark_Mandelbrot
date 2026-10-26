// pure mandelbrot.cs [width] [height] [maxIter]
// The C# version as a Pure 2 script: the same method, run by Pure's interpreter (Roslyn scripting), the command line read from Arguments.
static ulong Mandelbrot(int width, int height, int maxIter)
{
    int[] buffer = new int[width * height];
    ulong checksum = 0;

    double xMin = -2.0;
    double xMax = 1.0;
    double yMin = -1.5;
    double yMax = 1.5;

    double dx = (xMax - xMin) / (width - 1);
    double dy = (yMax - yMin) / (height - 1);

    int index = 0;
    for (int y = 0; y < height; y++)
    {
        double cy = yMin + y * dy;
        for (int x = 0; x < width; x++)
        {
            double cx = xMin + x * dx;

            double zx = 0.0;
            double zy = 0.0;
            int iter = 0;

            while (zx * zx + zy * zy <= 4.0 && iter < maxIter)
            {
                double zx2 = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = zx2;
                iter++;
            }

            buffer[index++] = iter;
            checksum += (ulong)iter;
        }
    }

    return checksum;
}

int width = Arguments.Length > 0 ? int.Parse(Arguments[0]) : 2000;
int height = Arguments.Length > 1 ? int.Parse(Arguments[1]) : 2000;
int maxIter = Arguments.Length > 2 ? int.Parse(Arguments[2]) : 1000;

Console.WriteLine(Mandelbrot(width, height, maxIter));
