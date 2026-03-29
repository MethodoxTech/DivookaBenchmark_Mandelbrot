def mandelbrot(width, height, max_iter)
  buffer = Array.new(width * height, 0)
  checksum = 0

  x_min = -2.0
  x_max = 1.0
  y_min = -1.5
  y_max = 1.5

  dx = (x_max - x_min) / (width - 1)
  dy = (y_max - y_min) / (height - 1)

  index = 0
  y = 0
  while y < height
    cy = y_min + y * dy

    x = 0
    while x < width
      cx = x_min + x * dx

      zx = 0.0
      zy = 0.0
      iter = 0

      while zx * zx + zy * zy <= 4.0 && iter < max_iter
        zx2 = zx * zx - zy * zy + cx
        zy = 2.0 * zx * zy + cy
        zx = zx2
        iter += 1
      end

      buffer[index] = iter
      checksum += iter
      index += 1
      x += 1
    end

    y += 1
  end

  checksum
end

width = 2000
height = 2000
max_iter = 1000

width = ARGV[0].to_i if ARGV.length > 0
height = ARGV[1].to_i if ARGV.length > 1
max_iter = ARGV[2].to_i if ARGV.length > 2

puts mandelbrot(width, height, max_iter)