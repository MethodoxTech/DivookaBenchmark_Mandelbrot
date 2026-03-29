#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

static uint64_t mandelbrot(int width, int height, int maxIter)
{
    std::vector<int> buffer(static_cast<size_t>(width) * height);
    uint64_t checksum = 0;

    const double xMin = -2.0;
    const double xMax = 1.0;
    const double yMin = -1.5;
    const double yMax = 1.5;

    const double dx = (xMax - xMin) / (width - 1);
    const double dy = (yMax - yMin) / (height - 1);

    for (int y = 0; y < height; ++y)
    {
        const double cy = yMin + y * dy;
        for (int x = 0; x < width; ++x)
        {
            const double cx = xMin + x * dx;

            double zx = 0.0;
            double zy = 0.0;
            int iter = 0;

            while (zx * zx + zy * zy <= 4.0 && iter < maxIter)
            {
                const double zx2 = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = zx2;
                ++iter;
            }

            buffer[static_cast<size_t>(y) * width + x] = iter;
            checksum += static_cast<uint64_t>(iter);
        }
    }

    return checksum;
}

int main(int argc, char** argv)
{
    int width = 2000;
    int height = 2000;
    int maxIter = 1000;

    if (argc > 1) width = std::atoi(argv[1]);
    if (argc > 2) height = std::atoi(argv[2]);
    if (argc > 3) maxIter = std::atoi(argv[3]);

    std::cout << mandelbrot(width, height, maxIter) << '\n';
    return 0;
}