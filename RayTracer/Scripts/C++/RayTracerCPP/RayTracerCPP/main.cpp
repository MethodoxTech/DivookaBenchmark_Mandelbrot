// Ray tracer benchmark, C++ - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
// raytracer <scene.txt> <output.ppm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

struct Vec
{
    double x, y, z;
};
static inline Vec operator+(Vec a, Vec b) { return { a.x + b.x, a.y + b.y, a.z + b.z }; }
static inline Vec operator-(Vec a, Vec b) { return { a.x - b.x, a.y - b.y, a.z - b.z }; }
static inline Vec operator*(Vec a, double s) { return { a.x * s, a.y * s, a.z * s }; }
static inline Vec operator*(Vec a, Vec b) { return { a.x * b.x, a.y * b.y, a.z * b.z }; }
static inline Vec operator/(Vec a, double s) { return { a.x / s, a.y / s, a.z / s }; }
static inline double dot(Vec a, Vec b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static inline Vec cross(Vec a, Vec b) { return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x }; }
static inline double length(Vec v) { return std::sqrt(dot(v, v)); }
static inline Vec normalize(Vec v) { return v * (1.0 / length(v)); }

struct Material
{
    Vec colour{}, other{};
    double scale = 0, diffuse = 0, specular = 0, reflect = 0;
    int shininess = 0;
};
struct Shape
{
    bool isSphere = false;
    Vec point{}, normal{};
    double radius = 0;
    const Material* material = nullptr;
};
struct Light
{
    Vec position, colour;
};

static const double Epsilon = 1e-4;
static const double Far = 1e30;

static int width = 320, height = 240, samples = 1, depth = 3;
static Vec eye{ 0, 0, 0 }, target{ 0, 0, 1 }, up{ 0, 1, 0 };
static double view = 0.5;
static Vec background{ 0, 0, 0 }, ambient{ 0, 0, 0 };
static std::vector<Light> lights;
static std::vector<Shape> shapes;
static std::map<std::string, std::unique_ptr<Material>> materials;

// The distance along the ray to the shape, or -1 when the ray misses it.
static double intersect(const Shape& shape, Vec origin, Vec direction)
{
    if (shape.isSphere)
    {
        Vec offset = origin - shape.point;
        double b = dot(offset, direction);
        double c = dot(offset, offset) - shape.radius * shape.radius;
        double discriminant = b * b - c;
        if (discriminant < 0)
            return -1;
        double root = std::sqrt(discriminant);
        double t = -b - root;
        if (t > Epsilon)
            return t;
        t = -b + root;
        return t > Epsilon ? t : -1;
    }
    double facing = dot(shape.normal, direction);
    if (std::fabs(facing) < 1e-9)
        return -1;
    double distance = dot(shape.point - origin, shape.normal) / facing;
    return distance > Epsilon ? distance : -1;
}

static bool shadowed(Vec origin, Vec direction, double distance)
{
    for (const Shape& shape : shapes)
    {
        double t = intersect(shape, origin, direction);
        if (t > Epsilon && t < distance)
            return true;
    }
    return false;
}

static Vec trace(Vec origin, Vec direction, int remaining)
{
    double nearest = Far;
    const Shape* hit = nullptr;
    for (const Shape& shape : shapes)
    {
        double t = intersect(shape, origin, direction);
        if (t > Epsilon && t < nearest)
        {
            nearest = t;
            hit = &shape;
        }
    }
    if (hit == nullptr)
        return background;

    Vec point = origin + direction * nearest;
    Vec normal = hit->isSphere ? (point - hit->point) / hit->radius : hit->normal;
    if (dot(normal, direction) > 0)
        normal = normal * -1.0;
    const Material& material = *hit->material;
    Vec colour = material.colour;
    if (material.scale > 0)
    {
        double k = std::floor(point.x / material.scale) + std::floor(point.z / material.scale);
        if (k - 2 * std::floor(k / 2) != 0)
            colour = material.other;
    }

    Vec result = ambient * colour;
    Vec lifted = point + normal * Epsilon;
    for (const Light& light : lights)
    {
        Vec toLight = light.position - point;
        double distance = length(toLight);
        Vec lightDirection = normalize(toLight);
        if (shadowed(lifted, lightDirection, distance))
            continue;
        double diffuse = dot(normal, lightDirection);
        if (diffuse > 0)
        {
            result = result + colour * light.colour * (material.diffuse * diffuse);
            Vec reflected = normal * (2 * diffuse) - lightDirection;
            double specular = -dot(reflected, direction);
            if (specular > 0)
            {
                double power = 1;
                for (int i = 0; i < material.shininess; i++)
                    power = power * specular;
                result = result + light.colour * (material.specular * power);
            }
        }
    }

    if (remaining > 0 && material.reflect > 0)
    {
        Vec bounced = direction - normal * (2 * dot(direction, normal));
        Vec mirrored = trace(lifted, bounced, remaining - 1);
        result = result * (1 - material.reflect) + mirrored * material.reflect;
    }
    return result;
}

static void load(const char* path)
{
    std::ifstream file(path);
    if (!file)
        throw std::runtime_error(std::string("Cannot open ") + path);
    std::string raw;
    while (std::getline(file, raw))
    {
        std::istringstream words(raw.substr(0, raw.find('#')));
        std::vector<std::string> w;
        for (std::string word; words >> word;)
            w.push_back(word);
        if (w.empty())
            continue;
        auto n = [&](size_t i) { return std::stod(w[i]); };
        auto v = [&](size_t i) { return Vec{ n(i), n(i + 1), n(i + 2) }; };
        const std::string& d = w[0];
        if (d == "size") { width = std::stoi(w[1]); height = std::stoi(w[2]); }
        else if (d == "samples") samples = std::stoi(w[1]);
        else if (d == "depth") depth = std::stoi(w[1]);
        else if (d == "camera") { eye = v(1); target = v(4); up = v(7); view = n(10); }
        else if (d == "background") background = v(1);
        else if (d == "ambient") ambient = v(1);
        else if (d == "light") lights.push_back({ v(1), v(4) });
        else if (d == "material")
        {
            auto m = std::make_unique<Material>();
            m->colour = v(2); m->other = v(2); m->diffuse = n(5); m->specular = n(6); m->shininess = std::stoi(w[7]); m->reflect = n(8);
            materials[w[1]] = std::move(m);
        }
        else if (d == "checker")
        {
            auto m = std::make_unique<Material>();
            m->colour = v(2); m->other = v(5); m->scale = n(8); m->diffuse = n(9); m->specular = n(10); m->shininess = std::stoi(w[11]); m->reflect = n(12);
            materials[w[1]] = std::move(m);
        }
        else if (d == "sphere")
        {
            Shape s; s.isSphere = true; s.point = v(1); s.radius = n(4); s.material = materials.at(w[5]).get();
            shapes.push_back(s);
        }
        else if (d == "plane")
        {
            Shape s; s.point = v(1); s.normal = normalize(v(4)); s.material = materials.at(w[7]).get();
            shapes.push_back(s);
        }
        else
            throw std::runtime_error("Unknown directive '" + d + "'.");
    }
}

int main(int argc, char** argv)
{
    if (argc < 3)
    {
        std::cerr << "Usage: raytracer <scene.txt> <output.ppm>\n";
        return 1;
    }
    load(argv[1]);

    Vec forward = normalize(target - eye);
    Vec right = normalize(cross(up, forward));
    Vec upward = cross(forward, right);
    double aspect = static_cast<double>(width) / height;

    std::vector<unsigned char> pixels(static_cast<size_t>(width) * height * 3);
    long long checksum = 0;
    size_t at = 0;
    for (int py = 0; py < height; py++)
        for (int px = 0; px < width; px++)
        {
            Vec colour{ 0, 0, 0 };
            for (int sy = 0; sy < samples; sy++)
                for (int sx = 0; sx < samples; sx++)
                {
                    double u = (px + (sx + 0.5) / samples) / width * 2 - 1;
                    double v = 1 - (py + (sy + 0.5) / samples) / height * 2;
                    Vec direction = normalize(forward + right * (u * aspect * view) + upward * (v * view));
                    colour = colour + trace(eye, direction, depth);
                }
            colour = colour / static_cast<double>(samples * samples);
            const double channels[3] = { colour.x, colour.y, colour.z };
            for (double channel : channels)
            {
                double c = channel < 0 ? 0 : channel > 1 ? 1 : channel;
                int value = static_cast<int>(std::floor(std::sqrt(c) * 255 + 0.5));
                pixels[at++] = static_cast<unsigned char>(value);
                checksum += value;
            }
        }

    std::ofstream out(argv[2], std::ios::binary);
    out << "P6\n" << width << ' ' << height << "\n255\n";
    out.write(reinterpret_cast<const char*>(pixels.data()), static_cast<std::streamsize>(pixels.size()));
    std::cout << "Checksum: " << checksum << '\n';
    return 0;
}
