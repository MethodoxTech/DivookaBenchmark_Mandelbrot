function mandelbrot_bench(varargin)
    width = 2000;
    height = 2000;
    maxIter = 1000;

    if nargin >= 1, width = str2double(varargin{1}); end
    if nargin >= 2, height = str2double(varargin{2}); end
    if nargin >= 3, maxIter = str2double(varargin{3}); end

    checksum = mandelbrot(width, height, maxIter);
    fprintf('%u\n', uint64(checksum));
end

function checksum = mandelbrot(width, height, maxIter)
    buffer = zeros(height, width, 'uint32');
    checksum = uint64(0);

    xMin = -2.0;
    xMax = 1.0;
    yMin = -1.5;
    yMax = 1.5;

    dx = (xMax - xMin) / (width - 1);
    dy = (yMax - yMin) / (height - 1);

    for y = 0:(height - 1)
        cy = yMin + y * dy;
        for x = 0:(width - 1)
            cx = xMin + x * dx;

            zx = 0.0;
            zy = 0.0;
            iter = uint32(0);

            while (zx * zx + zy * zy <= 4.0) && (iter < maxIter)
                zx2 = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = zx2;
                iter = iter + 1;
            end

            buffer(y + 1, x + 1) = iter;
            checksum = checksum + uint64(iter);
        end
    end
end

mandelbrot_bench()