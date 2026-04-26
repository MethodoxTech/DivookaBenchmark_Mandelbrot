function mandelbrot(width::Int, height::Int, max_iter::Int)::UInt64
    buffer = Vector{Int32}(undef, width * height)
    checksum::UInt64 = 0

    x_min = -2.0
    x_max = 1.0
    y_min = -1.5
    y_max = 1.5

    dx = (x_max - x_min) / (width - 1)
    dy = (y_max - y_min) / (height - 1)

    index = 1

    for y in 0:(height - 1)
        cy = y_min + y * dy

        for x in 0:(width - 1)
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
            checksum += UInt64(iter)
            index += 1
        end
    end

    return checksum
end

function main()
    width = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 2000
    height = length(ARGS) > 1 ? parse(Int, ARGS[2]) : 2000
    max_iter = length(ARGS) > 2 ? parse(Int, ARGS[3]) : 1000

    println(mandelbrot(width, height, max_iter))
end

main()