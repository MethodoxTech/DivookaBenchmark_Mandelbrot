# Ray tracer benchmark, Julia - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
# julia raytracer.jl <scene.txt> <output.ppm>
# Julia never fuses a multiply and an add unless asked to (muladd, @fastmath), and this asks nowhere.

struct Vec
    x::Float64
    y::Float64
    z::Float64
end

add(a::Vec, b::Vec) = Vec(a.x + b.x, a.y + b.y, a.z + b.z)
sub(a::Vec, b::Vec) = Vec(a.x - b.x, a.y - b.y, a.z - b.z)
scale(a::Vec, s::Float64) = Vec(a.x * s, a.y * s, a.z * s)
mul(a::Vec, b::Vec) = Vec(a.x * b.x, a.y * b.y, a.z * b.z)
divide(a::Vec, s::Float64) = Vec(a.x / s, a.y / s, a.z / s)
dot(a::Vec, b::Vec) = a.x * b.x + a.y * b.y + a.z * b.z
cross(a::Vec, b::Vec) = Vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
vlength(v::Vec) = sqrt(dot(v, v))
normalize(v::Vec) = scale(v, 1.0 / vlength(v))

struct Material
    colour::Vec
    other::Vec
    scale::Float64
    diffuse::Float64
    specular::Float64
    shininess::Int
    reflect::Float64
end

struct Shape
    is_sphere::Bool
    point::Vec
    normal::Vec
    radius::Float64
    material::Material
end

struct Light
    position::Vec
    colour::Vec
end

mutable struct Scene
    width::Int
    height::Int
    samples::Int
    depth::Int
    eye::Vec
    target::Vec
    up::Vec
    view::Float64
    background::Vec
    ambient::Vec
    lights::Vector{Light}
    shapes::Vector{Shape}
    materials::Dict{String,Material}
end

const EPSILON = 1e-4
const FAR = 1e30

# The distance along the ray to the shape, or -1 when the ray misses it.
function intersect(shape::Shape, origin::Vec, direction::Vec)::Float64
    if shape.is_sphere
        offset = sub(origin, shape.point)
        b = dot(offset, direction)
        c = dot(offset, offset) - shape.radius * shape.radius
        discriminant = b * b - c
        discriminant < 0 && return -1.0
        root = sqrt(discriminant)
        t = -b - root
        t > EPSILON && return t
        t = -b + root
        return t > EPSILON ? t : -1.0
    end
    facing = dot(shape.normal, direction)
    abs(facing) < 1e-9 && return -1.0
    distance = dot(sub(shape.point, origin), shape.normal) / facing
    return distance > EPSILON ? distance : -1.0
end

function shadowed(scene::Scene, origin::Vec, direction::Vec, distance::Float64)::Bool
    for shape in scene.shapes
        t = intersect(shape, origin, direction)
        (t > EPSILON && t < distance) && return true
    end
    return false
end

function trace(scene::Scene, origin::Vec, direction::Vec, remaining::Int)::Vec
    nearest = FAR
    hit = 0
    for (index, shape) in enumerate(scene.shapes)
        t = intersect(shape, origin, direction)
        if t > EPSILON && t < nearest
            nearest = t
            hit = index
        end
    end
    hit == 0 && return scene.background
    shape = scene.shapes[hit]

    point = add(origin, scale(direction, nearest))
    normal = shape.is_sphere ? divide(sub(point, shape.point), shape.radius) : shape.normal
    if dot(normal, direction) > 0
        normal = scale(normal, -1.0)
    end
    material = shape.material
    colour = material.colour
    if material.scale > 0
        k = floor(point.x / material.scale) + floor(point.z / material.scale)
        if k - 2 * floor(k / 2) != 0
            colour = material.other
        end
    end

    result = mul(scene.ambient, colour)
    lifted = add(point, scale(normal, EPSILON))
    for light in scene.lights
        to_light = sub(light.position, point)
        distance = vlength(to_light)
        light_direction = normalize(to_light)
        shadowed(scene, lifted, light_direction, distance) && continue
        diffuse = dot(normal, light_direction)
        if diffuse > 0
            result = add(result, scale(mul(colour, light.colour), material.diffuse * diffuse))
            reflected = sub(scale(normal, 2 * diffuse), light_direction)
            specular = -dot(reflected, direction)
            if specular > 0
                power = 1.0
                for _ in 1:material.shininess
                    power = power * specular
                end
                result = add(result, scale(light.colour, material.specular * power))
            end
        end
    end

    if remaining > 0 && material.reflect > 0
        bounced = sub(direction, scale(normal, 2 * dot(direction, normal)))
        mirrored = trace(scene, lifted, bounced, remaining - 1)
        result = add(scale(result, 1 - material.reflect), scale(mirrored, material.reflect))
    end
    return result
end

function load(path::String)::Scene
    zero = Vec(0.0, 0.0, 0.0)
    scene = Scene(320, 240, 1, 3, zero, Vec(0.0, 0.0, 1.0), Vec(0.0, 1.0, 0.0), 0.5, zero, zero, Light[], Shape[], Dict{String,Material}())
    for raw in eachline(path)
        w = split(split(raw, '#'; limit=2)[1])
        isempty(w) && continue
        n(i) = parse(Float64, w[i + 1])
        v(i) = Vec(n(i), n(i + 1), n(i + 2))
        d = w[1]
        if d == "size"
            scene.width = parse(Int, w[2]); scene.height = parse(Int, w[3])
        elseif d == "samples"
            scene.samples = parse(Int, w[2])
        elseif d == "depth"
            scene.depth = parse(Int, w[2])
        elseif d == "camera"
            scene.eye = v(1); scene.target = v(4); scene.up = v(7); scene.view = n(10)
        elseif d == "background"
            scene.background = v(1)
        elseif d == "ambient"
            scene.ambient = v(1)
        elseif d == "light"
            push!(scene.lights, Light(v(1), v(4)))
        elseif d == "material"
            scene.materials[w[2]] = Material(v(2), v(2), 0.0, n(5), n(6), parse(Int, w[8]), n(8))
        elseif d == "checker"
            scene.materials[w[2]] = Material(v(2), v(5), n(8), n(9), n(10), parse(Int, w[12]), n(12))
        elseif d == "sphere"
            push!(scene.shapes, Shape(true, v(1), zero, n(4), scene.materials[w[6]]))
        elseif d == "plane"
            push!(scene.shapes, Shape(false, v(1), normalize(v(4)), 0.0, scene.materials[w[8]]))
        else
            error("Unknown directive '$(d)'.")
        end
    end
    return scene
end

function render(scene::Scene)
    width, height, samples, view = scene.width, scene.height, scene.samples, scene.view
    forward = normalize(sub(scene.target, scene.eye))
    right = normalize(cross(scene.up, forward))
    upward = cross(forward, right)
    aspect = width / height

    pixels = Vector{UInt8}(undef, width * height * 3)
    checksum = 0
    at = 1
    for py in 0:(height - 1)
        for px in 0:(width - 1)
            colour = Vec(0.0, 0.0, 0.0)
            for sy in 0:(samples - 1)
                for sx in 0:(samples - 1)
                    u = (px + (sx + 0.5) / samples) / width * 2 - 1
                    v = 1 - (py + (sy + 0.5) / samples) / height * 2
                    direction = normalize(add(add(forward, scale(right, u * aspect * view)), scale(upward, v * view)))
                    colour = add(colour, trace(scene, scene.eye, direction, scene.depth))
                end
            end
            colour = divide(colour, Float64(samples * samples))
            for channel in (colour.x, colour.y, colour.z)
                c = channel < 0 ? 0.0 : (channel > 1 ? 1.0 : channel)
                value = Int(floor(sqrt(c) * 255 + 0.5))
                pixels[at] = UInt8(value)
                at += 1
                checksum += value
            end
        end
    end
    return pixels, checksum
end

function main()
    if length(ARGS) < 2
        println(stderr, "Usage: raytracer <scene.txt> <output.ppm>")
        exit(1)
    end
    scene = load(ARGS[1])
    pixels, checksum = render(scene)
    open(ARGS[2], "w") do out
        write(out, "P6\n$(scene.width) $(scene.height)\n255\n")
        write(out, pixels)
    end
    println("Checksum: $(checksum)")
end

main()
