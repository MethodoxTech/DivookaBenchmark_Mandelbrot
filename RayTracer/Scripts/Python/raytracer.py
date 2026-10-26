# Ray tracer benchmark, Python - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
# python raytracer.py <scene.txt> <output.ppm>
import math
import sys

EPSILON = 1e-4
FAR = 1e30


class Vec:
    __slots__ = ("x", "y", "z")

    def __init__(self, x, y, z):
        self.x = x
        self.y = y
        self.z = z


def add(a, b): return Vec(a.x + b.x, a.y + b.y, a.z + b.z)
def sub(a, b): return Vec(a.x - b.x, a.y - b.y, a.z - b.z)
def scale(a, s): return Vec(a.x * s, a.y * s, a.z * s)
def mul(a, b): return Vec(a.x * b.x, a.y * b.y, a.z * b.z)
def div(a, s): return Vec(a.x / s, a.y / s, a.z / s)
def dot(a, b): return a.x * b.x + a.y * b.y + a.z * b.z
def cross(a, b): return Vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
def length(v): return math.sqrt(dot(v, v))
def normalize(v): return scale(v, 1.0 / length(v))


class Material:
    __slots__ = ("colour", "other", "scale", "diffuse", "specular", "shininess", "reflect")


class Shape:
    __slots__ = ("is_sphere", "point", "normal", "radius", "material")


class Scene:
    def __init__(self):
        self.width, self.height, self.samples, self.depth = 320, 240, 1, 3
        self.eye, self.target, self.up, self.view = Vec(0.0, 0.0, 0.0), Vec(0.0, 0.0, 1.0), Vec(0.0, 1.0, 0.0), 0.5
        self.background, self.ambient = Vec(0.0, 0.0, 0.0), Vec(0.0, 0.0, 0.0)
        self.lights = []
        self.shapes = []
        self.materials = {}


def intersect(shape, origin, direction):
    """The distance along the ray to the shape, or -1 when the ray misses it."""
    if shape.is_sphere:
        offset = sub(origin, shape.point)
        b = dot(offset, direction)
        c = dot(offset, offset) - shape.radius * shape.radius
        discriminant = b * b - c
        if discriminant < 0:
            return -1.0
        root = math.sqrt(discriminant)
        t = -b - root
        if t > EPSILON:
            return t
        t = -b + root
        return t if t > EPSILON else -1.0
    facing = dot(shape.normal, direction)
    if abs(facing) < 1e-9:
        return -1.0
    distance = dot(sub(shape.point, origin), shape.normal) / facing
    return distance if distance > EPSILON else -1.0


def shadowed(scene, origin, direction, distance):
    for shape in scene.shapes:
        t = intersect(shape, origin, direction)
        if t > EPSILON and t < distance:
            return True
    return False


def trace(scene, origin, direction, remaining):
    nearest = FAR
    hit = None
    for shape in scene.shapes:
        t = intersect(shape, origin, direction)
        if t > EPSILON and t < nearest:
            nearest = t
            hit = shape
    if hit is None:
        return scene.background

    point = add(origin, scale(direction, nearest))
    normal = div(sub(point, hit.point), hit.radius) if hit.is_sphere else hit.normal
    if dot(normal, direction) > 0:
        normal = scale(normal, -1.0)
    material = hit.material
    colour = material.colour
    if material.scale > 0:
        k = float(math.floor(point.x / material.scale)) + float(math.floor(point.z / material.scale))
        if k - 2 * float(math.floor(k / 2)) != 0:
            colour = material.other

    result = mul(scene.ambient, colour)
    lifted = add(point, scale(normal, EPSILON))
    for position, light_colour in scene.lights:
        to_light = sub(position, point)
        distance = length(to_light)
        light_direction = normalize(to_light)
        if shadowed(scene, lifted, light_direction, distance):
            continue
        diffuse = dot(normal, light_direction)
        if diffuse > 0:
            result = add(result, scale(mul(colour, light_colour), material.diffuse * diffuse))
            reflected = sub(scale(normal, 2 * diffuse), light_direction)
            specular = -dot(reflected, direction)
            if specular > 0:
                power = 1.0
                for _ in range(material.shininess):
                    power = power * specular
                result = add(result, scale(light_colour, material.specular * power))

    if remaining > 0 and material.reflect > 0:
        bounced = sub(direction, scale(normal, 2 * dot(direction, normal)))
        mirrored = trace(scene, lifted, bounced, remaining - 1)
        result = add(scale(result, 1 - material.reflect), scale(mirrored, material.reflect))
    return result


def load(path):
    scene = Scene()
    with open(path, encoding="utf-8") as file:
        for raw in file:
            w = raw.split("#", 1)[0].split()
            if not w:
                continue
            n = lambda i: float(w[i])
            v = lambda i: Vec(n(i), n(i + 1), n(i + 2))
            d = w[0]
            if d == "size":
                scene.width, scene.height = int(w[1]), int(w[2])
            elif d == "samples":
                scene.samples = int(w[1])
            elif d == "depth":
                scene.depth = int(w[1])
            elif d == "camera":
                scene.eye, scene.target, scene.up, scene.view = v(1), v(4), v(7), n(10)
            elif d == "background":
                scene.background = v(1)
            elif d == "ambient":
                scene.ambient = v(1)
            elif d == "light":
                scene.lights.append((v(1), v(4)))
            elif d == "material":
                m = Material()
                m.colour, m.other, m.scale = v(2), v(2), 0.0
                m.diffuse, m.specular, m.shininess, m.reflect = n(5), n(6), int(w[7]), n(8)
                scene.materials[w[1]] = m
            elif d == "checker":
                m = Material()
                m.colour, m.other, m.scale = v(2), v(5), n(8)
                m.diffuse, m.specular, m.shininess, m.reflect = n(9), n(10), int(w[11]), n(12)
                scene.materials[w[1]] = m
            elif d == "sphere":
                s = Shape()
                s.is_sphere, s.point, s.normal, s.radius, s.material = True, v(1), Vec(0.0, 0.0, 0.0), n(4), scene.materials[w[5]]
                scene.shapes.append(s)
            elif d == "plane":
                s = Shape()
                s.is_sphere, s.point, s.normal, s.radius, s.material = False, v(1), normalize(v(4)), 0.0, scene.materials[w[7]]
                scene.shapes.append(s)
            else:
                raise ValueError(f"Unknown directive '{d}'.")
    return scene


def main():
    if len(sys.argv) < 3:
        print("Usage: raytracer <scene.txt> <output.ppm>", file=sys.stderr)
        sys.exit(1)
    scene = load(sys.argv[1])
    width, height, samples = scene.width, scene.height, scene.samples

    forward = normalize(sub(scene.target, scene.eye))
    right = normalize(cross(scene.up, forward))
    upward = cross(forward, right)
    aspect = width / height
    view = scene.view

    pixels = bytearray(width * height * 3)
    checksum = 0
    at = 0
    for py in range(height):
        for px in range(width):
            colour = Vec(0.0, 0.0, 0.0)
            for sy in range(samples):
                for sx in range(samples):
                    u = (px + (sx + 0.5) / samples) / width * 2 - 1
                    v = 1 - (py + (sy + 0.5) / samples) / height * 2
                    direction = normalize(add(add(forward, scale(right, u * aspect * view)), scale(upward, v * view)))
                    colour = add(colour, trace(scene, scene.eye, direction, scene.depth))
            colour = div(colour, float(samples * samples))
            for channel in (colour.x, colour.y, colour.z):
                c = 0.0 if channel < 0 else 1.0 if channel > 1 else channel
                value = math.floor(math.sqrt(c) * 255 + 0.5)
                pixels[at] = value
                at += 1
                checksum += value

    with open(sys.argv[2], "wb") as out:
        out.write(f"P6\n{width} {height}\n255\n".encode("ascii"))
        out.write(pixels)
    print(f"Checksum: {checksum}")


if __name__ == "__main__":
    main()
