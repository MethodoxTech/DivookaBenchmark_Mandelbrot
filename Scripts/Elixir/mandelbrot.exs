# elixir mandelbrot.exs [width] [height] [maxIter]
defmodule Mandelbrot do
  def checksum(width, height, max_iter) do
    x_min = -2.0
    x_max = 1.0
    y_min = -1.5
    y_max = 1.5

    dx = (x_max - x_min) / (width - 1)
    dy = (y_max - y_min) / (height - 1)

    rows(0, height, width, max_iter, x_min, y_min, dx, dy, 0)
  end

  defp rows(y, height, _width, _max_iter, _x_min, _y_min, _dx, _dy, acc) when y >= height, do: acc

  defp rows(y, height, width, max_iter, x_min, y_min, dx, dy, acc) do
    cy = y_min + y * dy
    acc = columns(0, width, max_iter, x_min, cy, dx, acc)
    rows(y + 1, height, width, max_iter, x_min, y_min, dx, dy, acc)
  end

  defp columns(x, width, _max_iter, _x_min, _cy, _dx, acc) when x >= width, do: acc

  defp columns(x, width, max_iter, x_min, cy, dx, acc) do
    cx = x_min + x * dx
    columns(x + 1, width, max_iter, x_min, cy, dx, acc + iterate(cx, cy, 0.0, 0.0, 0, max_iter))
  end

  defp iterate(cx, cy, zx, zy, iter, max_iter) do
    if zx * zx + zy * zy <= 4.0 and iter < max_iter do
      zx2 = zx * zx - zy * zy + cx
      iterate(cx, cy, zx2, 2.0 * zx * zy + cy, iter + 1, max_iter)
    else
      iter
    end
  end
end

[width, height, max_iter] =
  case System.argv() do
    [w, h, i | _] -> [String.to_integer(w), String.to_integer(h), String.to_integer(i)]
    [w, h] -> [String.to_integer(w), String.to_integer(h), 1000]
    [w] -> [String.to_integer(w), 2000, 1000]
    [] -> [2000, 2000, 1000]
  end

IO.puts(Mandelbrot.checksum(width, height, max_iter))
