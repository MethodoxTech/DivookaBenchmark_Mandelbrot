# Ray tracer benchmark, Ruby - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
# ruby raytracer.rb <scene.txt> <output.ppm>

EPSILON = 1e-4
FAR = 1e30

Vec = Struct.new(:x, :y, :z)

def add(a, b) = Vec.new(a.x + b.x, a.y + b.y, a.z + b.z)
def sub(a, b) = Vec.new(a.x - b.x, a.y - b.y, a.z - b.z)
def scale(a, s) = Vec.new(a.x * s, a.y * s, a.z * s)
def mul(a, b) = Vec.new(a.x * b.x, a.y * b.y, a.z * b.z)
def div(a, s) = Vec.new(a.x / s, a.y / s, a.z / s)
def dot(a, b) = a.x * b.x + a.y * b.y + a.z * b.z
def cross(a, b) = Vec.new(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
def length(v) = Math.sqrt(dot(v, v))
def normalize(v) = scale(v, 1.0 / length(v))

Material = Struct.new(:colour, :other, :scale, :diffuse, :specular, :shininess, :reflect)
Shape = Struct.new(:is_sphere, :point, :normal, :radius, :material)
Light = Struct.new(:position, :colour)

class Scene
  attr_accessor :width, :height, :samples, :depth, :eye, :target, :up, :view, :background, :ambient, :lights, :shapes, :materials

  def initialize
    @width, @height, @samples, @depth = 320, 240, 1, 3
    @eye, @target, @up, @view = Vec.new(0.0, 0.0, 0.0), Vec.new(0.0, 0.0, 1.0), Vec.new(0.0, 1.0, 0.0), 0.5
    @background, @ambient = Vec.new(0.0, 0.0, 0.0), Vec.new(0.0, 0.0, 0.0)
    @lights, @shapes, @materials = [], [], {}
  end
end

# The distance along the ray to the shape, or -1 when the ray misses it.
def intersect(shape, origin, direction)
  if shape.is_sphere
    offset = sub(origin, shape.point)
    b = dot(offset, direction)
    c = dot(offset, offset) - shape.radius * shape.radius
    discriminant = b * b - c
    return -1.0 if discriminant < 0
    root = Math.sqrt(discriminant)
    t = -b - root
    return t if t > EPSILON
    t = -b + root
    return t > EPSILON ? t : -1.0
  end
  facing = dot(shape.normal, direction)
  return -1.0 if facing.abs < 1e-9
  distance = dot(sub(shape.point, origin), shape.normal) / facing
  distance > EPSILON ? distance : -1.0
end

def shadowed(scene, origin, direction, distance)
  scene.shapes.each do |shape|
    t = intersect(shape, origin, direction)
    return true if t > EPSILON && t < distance
  end
  false
end

def trace(scene, origin, direction, remaining)
  nearest = FAR
  hit = nil
  scene.shapes.each do |shape|
    t = intersect(shape, origin, direction)
    if t > EPSILON && t < nearest
      nearest = t
      hit = shape
    end
  end
  return scene.background if hit.nil?

  point = add(origin, scale(direction, nearest))
  normal = hit.is_sphere ? div(sub(point, hit.point), hit.radius) : hit.normal
  normal = scale(normal, -1.0) if dot(normal, direction) > 0
  material = hit.material
  colour = material.colour
  if material.scale > 0
    k = (point.x / material.scale).floor.to_f + (point.z / material.scale).floor.to_f
    colour = material.other if k - 2 * (k / 2).floor.to_f != 0
  end

  result = mul(scene.ambient, colour)
  lifted = add(point, scale(normal, EPSILON))
  scene.lights.each do |light|
    to_light = sub(light.position, point)
    distance = length(to_light)
    light_direction = normalize(to_light)
    next if shadowed(scene, lifted, light_direction, distance)
    diffuse = dot(normal, light_direction)
    if diffuse > 0
      result = add(result, scale(mul(colour, light.colour), material.diffuse * diffuse))
      reflected = sub(scale(normal, 2 * diffuse), light_direction)
      specular = -dot(reflected, direction)
      if specular > 0
        power = 1.0
        material.shininess.times { power = power * specular }
        result = add(result, scale(light.colour, material.specular * power))
      end
    end
  end

  if remaining > 0 && material.reflect > 0
    bounced = sub(direction, scale(normal, 2 * dot(direction, normal)))
    mirrored = trace(scene, lifted, bounced, remaining - 1)
    result = add(scale(result, 1 - material.reflect), scale(mirrored, material.reflect))
  end
  result
end

def load(path)
  scene = Scene.new
  File.foreach(path) do |raw|
    w = raw.split('#', 2)[0].split
    next if w.empty?
    n = ->(i) { Float(w[i]) }
    v = ->(i) { Vec.new(n.(i), n.(i + 1), n.(i + 2)) }
    case w[0]
    when 'size' then scene.width, scene.height = Integer(w[1]), Integer(w[2])
    when 'samples' then scene.samples = Integer(w[1])
    when 'depth' then scene.depth = Integer(w[1])
    when 'camera' then scene.eye, scene.target, scene.up, scene.view = v.(1), v.(4), v.(7), n.(10)
    when 'background' then scene.background = v.(1)
    when 'ambient' then scene.ambient = v.(1)
    when 'light' then scene.lights << Light.new(v.(1), v.(4))
    when 'material' then scene.materials[w[1]] = Material.new(v.(2), v.(2), 0.0, n.(5), n.(6), Integer(w[7]), n.(8))
    when 'checker' then scene.materials[w[1]] = Material.new(v.(2), v.(5), n.(8), n.(9), n.(10), Integer(w[11]), n.(12))
    when 'sphere' then scene.shapes << Shape.new(true, v.(1), Vec.new(0.0, 0.0, 0.0), n.(4), scene.materials[w[5]])
    when 'plane' then scene.shapes << Shape.new(false, v.(1), normalize(v.(4)), 0.0, scene.materials[w[7]])
    else raise "Unknown directive '#{w[0]}'."
    end
  end
  scene
end

if ARGV.length < 2
  warn 'Usage: raytracer <scene.txt> <output.ppm>'
  exit 1
end
scene = load(ARGV[0])
width, height, samples, view = scene.width, scene.height, scene.samples, scene.view

forward = normalize(sub(scene.target, scene.eye))
right = normalize(cross(scene.up, forward))
upward = cross(forward, right)
aspect = width.to_f / height

pixels = Array.new(width * height * 3, 0)
checksum = 0
at = 0
height.times do |py|
  width.times do |px|
    colour = Vec.new(0.0, 0.0, 0.0)
    samples.times do |sy|
      samples.times do |sx|
        u = (px + (sx + 0.5) / samples) / width * 2 - 1
        v = 1 - (py + (sy + 0.5) / samples) / height * 2
        direction = normalize(add(add(forward, scale(right, u * aspect * view)), scale(upward, v * view)))
        colour = add(colour, trace(scene, scene.eye, direction, scene.depth))
      end
    end
    colour = div(colour, (samples * samples).to_f)
    [colour.x, colour.y, colour.z].each do |channel|
      c = channel < 0 ? 0.0 : (channel > 1 ? 1.0 : channel)
      value = (Math.sqrt(c) * 255 + 0.5).floor
      pixels[at] = value
      at += 1
      checksum += value
    end
  end
end

File.open(ARGV[1], 'wb') do |out|
  out.write("P6\n#{width} #{height}\n255\n")
  out.write(pixels.pack('C*'))
end
puts "Checksum: #{checksum}"
