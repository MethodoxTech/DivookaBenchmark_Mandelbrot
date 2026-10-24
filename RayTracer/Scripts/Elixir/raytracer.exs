# Ray tracer benchmark, Elixir - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
# elixir raytracer.exs <scene.txt> <output.ppm>
# A vector is a tuple {x, y, z}; every number is an IEEE double, and `/` always divides as one.
defmodule RayTracer do
  @epsilon 1.0e-4
  @far 1.0e30

  def add({a, b, c}, {x, y, z}), do: {a + x, b + y, c + z}
  def sub({a, b, c}, {x, y, z}), do: {a - x, b - y, c - z}
  def scale({a, b, c}, s), do: {a * s, b * s, c * s}
  def mul({a, b, c}, {x, y, z}), do: {a * x, b * y, c * z}
  def divide({a, b, c}, s), do: {a / s, b / s, c / s}
  def dot({a, b, c}, {x, y, z}), do: a * x + b * y + c * z
  def cross({ax, ay, az}, {bx, by, bz}), do: {ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx}
  def vlength(v), do: :math.sqrt(dot(v, v))
  def normalize(v), do: scale(v, 1.0 / vlength(v))

  # The distance along the ray to the shape, or -1 when the ray misses it.
  def intersect(%{kind: :sphere, point: centre, radius: radius}, origin, direction) do
    offset = sub(origin, centre)
    b = dot(offset, direction)
    c = dot(offset, offset) - radius * radius
    discriminant = b * b - c

    if discriminant < 0 do
      -1.0
    else
      root = :math.sqrt(discriminant)
      t = -b - root

      if t > @epsilon do
        t
      else
        t = -b + root
        if t > @epsilon, do: t, else: -1.0
      end
    end
  end

  def intersect(%{kind: :plane, point: point, normal: normal}, origin, direction) do
    facing = dot(normal, direction)

    if abs(facing) < 1.0e-9 do
      -1.0
    else
      distance = dot(sub(point, origin), normal) / facing
      if distance > @epsilon, do: distance, else: -1.0
    end
  end

  def shadowed(scene, origin, direction, distance) do
    Enum.any?(scene.shapes, fn shape ->
      t = intersect(shape, origin, direction)
      t > @epsilon and t < distance
    end)
  end

  def power(_x, 0, acc), do: acc
  def power(x, n, acc), do: power(x, n - 1, acc * x)

  def trace(scene, origin, direction, remaining) do
    {nearest, hit} =
      Enum.reduce(scene.shapes, {@far, nil}, fn shape, {nearest, hit} ->
        t = intersect(shape, origin, direction)
        if t > @epsilon and t < nearest, do: {t, shape}, else: {nearest, hit}
      end)

    if hit == nil do
      scene.background
    else
      point = add(origin, scale(direction, nearest))
      normal = if hit.kind == :sphere, do: divide(sub(point, hit.point), hit.radius), else: hit.normal
      normal = if dot(normal, direction) > 0, do: scale(normal, -1.0), else: normal
      material = hit.material
      {px, _, pz} = point

      colour =
        if material.scale > 0 do
          k = Float.floor(px / material.scale) + Float.floor(pz / material.scale)
          if k - 2 * Float.floor(k / 2) != 0, do: material.other, else: material.colour
        else
          material.colour
        end

      lifted = add(point, scale(normal, @epsilon))

      shaded =
        Enum.reduce(scene.lights, mul(scene.ambient, colour), fn {position, light_colour}, result ->
          to_light = sub(position, point)
          distance = vlength(to_light)
          light_direction = normalize(to_light)

          if shadowed(scene, lifted, light_direction, distance) do
            result
          else
            diffuse = dot(normal, light_direction)

            if diffuse > 0 do
              result = add(result, scale(mul(colour, light_colour), material.diffuse * diffuse))
              reflected = sub(scale(normal, 2 * diffuse), light_direction)
              specular = -dot(reflected, direction)

              if specular > 0,
                do: add(result, scale(light_colour, material.specular * power(specular, material.shininess, 1.0))),
                else: result
            else
              result
            end
          end
        end)

      if remaining > 0 and material.reflect > 0 do
        bounced = sub(direction, scale(normal, 2 * dot(direction, normal)))
        mirrored = trace(scene, lifted, bounced, remaining - 1)
        add(scale(shaded, 1 - material.reflect), scale(mirrored, material.reflect))
      else
        shaded
      end
    end
  end

  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  def load(path) do
    initial = %{
      width: 320, height: 240, samples: 1, depth: 3,
      eye: {0.0, 0.0, 0.0}, target: {0.0, 0.0, 1.0}, up: {0.0, 1.0, 0.0}, view: 0.5,
      background: {0.0, 0.0, 0.0}, ambient: {0.0, 0.0, 0.0},
      lights: [], shapes: [], materials: %{}
    }

    scene =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reduce(initial, fn raw, scene ->
        [line | _] = String.split(raw, "#", parts: 2)
        w = List.to_tuple(String.split(line))
        n = fn i -> number(elem(w, i)) end
        v = fn i -> {n.(i), n.(i + 1), n.(i + 2)} end
        int = fn i -> String.to_integer(elem(w, i)) end

        case tuple_size(w) do
          0 ->
            scene

          _ ->
            case elem(w, 0) do
              "size" -> %{scene | width: int.(1), height: int.(2)}
              "samples" -> %{scene | samples: int.(1)}
              "depth" -> %{scene | depth: int.(1)}
              "camera" -> %{scene | eye: v.(1), target: v.(4), up: v.(7), view: n.(10)}
              "background" -> %{scene | background: v.(1)}
              "ambient" -> %{scene | ambient: v.(1)}
              "light" -> %{scene | lights: [{v.(1), v.(4)} | scene.lights]}
              "material" ->
                material = %{colour: v.(2), other: v.(2), scale: 0.0, diffuse: n.(5), specular: n.(6), shininess: int.(7), reflect: n.(8)}
                %{scene | materials: Map.put(scene.materials, elem(w, 1), material)}
              "checker" ->
                material = %{colour: v.(2), other: v.(5), scale: n.(8), diffuse: n.(9), specular: n.(10), shininess: int.(11), reflect: n.(12)}
                %{scene | materials: Map.put(scene.materials, elem(w, 1), material)}
              "sphere" ->
                shape = %{kind: :sphere, point: v.(1), normal: {0.0, 0.0, 0.0}, radius: n.(4), material: Map.fetch!(scene.materials, elem(w, 5))}
                %{scene | shapes: [shape | scene.shapes]}
              "plane" ->
                shape = %{kind: :plane, point: v.(1), normal: normalize(v.(4)), radius: 0.0, material: Map.fetch!(scene.materials, elem(w, 7))}
                %{scene | shapes: [shape | scene.shapes]}
              other -> raise "Unknown directive '#{other}'."
            end
        end
      end)

    # Built by prepending, so put back into the file's order: the nearest of two equal hits is the first in the file.
    %{scene | lights: Enum.reverse(scene.lights), shapes: Enum.reverse(scene.shapes)}
  end

  def render(scene) do
    %{width: w, height: h, samples: s, view: view} = scene
    forward = normalize(sub(scene.target, scene.eye))
    right = normalize(cross(scene.up, forward))
    upward = cross(forward, right)
    aspect = w / h

    for py <- 0..(h - 1), px <- 0..(w - 1), reduce: {[], 0} do
      {rows, checksum} ->
        colour =
          for sy <- 0..(s - 1), sx <- 0..(s - 1), reduce: {0.0, 0.0, 0.0} do
            acc ->
              u = (px + (sx + 0.5) / s) / w * 2 - 1
              v = 1 - (py + (sy + 0.5) / s) / h * 2
              direction = normalize(add(add(forward, scale(right, u * aspect * view)), scale(upward, v * view)))
              add(acc, trace(scene, scene.eye, direction, scene.depth))
          end

        {r, g, b} = divide(colour, s * s * 1.0)
        values = Enum.map([r, g, b], fn channel ->
          c = if channel < 0, do: 0.0, else: if(channel > 1, do: 1.0, else: channel)
          trunc(Float.floor(:math.sqrt(c) * 255 + 0.5))
        end)
        {[values | rows], checksum + Enum.sum(values)}
    end
  end

  def main([scene_path, output_path | _]) do
    scene = load(scene_path)
    {rows, checksum} = render(scene)
    header = "P6\n#{scene.width} #{scene.height}\n255\n"
    File.write!(output_path, [header, :erlang.list_to_binary(Enum.reverse(rows))])
    IO.puts("Checksum: #{checksum}")
  end

  def main(_) do
    IO.puts(:stderr, "Usage: raytracer <scene.txt> <output.ppm>")
    System.halt(1)
  end
end

RayTracer.main(System.argv())
