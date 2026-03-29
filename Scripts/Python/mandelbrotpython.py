import sys


def mandelbrot(width: int, height: int, max_iter: int) -> int:
    buffer = [0] * (width * height)
    checksum = 0

    x_min = -2.0
    x_max = 1.0
    y_min = -1.5
    y_max = 1.5

    dx = (x_max - x_min) / (width - 1)
    dy = (y_max - y_min) / (height - 1)

    index = 0
    for y in range(height):
        cy = y_min + y * dy
        for x in range(width):
            cx = x_min + x * dx

            zx = 0.0
            zy = 0.0
            it = 0

            while zx * zx + zy * zy <= 4.0 and it < max_iter:
                zx2 = zx * zx - zy * zy + cx
                zy = 2.0 * zx * zy + cy
                zx = zx2
                it += 1

            buffer[index] = it
            checksum += it
            index += 1

    return checksum


def main() -> None:
    width = 2000
    height = 2000
    max_iter = 1000

    if len(sys.argv) > 1:
        width = int(sys.argv[1])
    if len(sys.argv) > 2:
        height = int(sys.argv[2])
    if len(sys.argv) > 3:
        max_iter = int(sys.argv[3])

    print(mandelbrot(width, height, max_iter))


if __name__ == "__main__":
    main()