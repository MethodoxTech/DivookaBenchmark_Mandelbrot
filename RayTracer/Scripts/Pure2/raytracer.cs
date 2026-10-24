// Ray tracer benchmark, Pure 2 - the C# reference (RayTracer/Scripts/C#) as a Pure 2 script, run by Pure's interpreter (Roslyn scripting).
// pure raytracer.cs <scene.txt> <output.ppm>
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

public static class RayTracer
{
    private const double Epsilon = 1e-4;
    private const double Far = 1e30;

    private readonly record struct Vec(double X, double Y, double Z)
    {
        public static Vec operator +(Vec a, Vec b) => new(a.X + b.X, a.Y + b.Y, a.Z + b.Z);
        public static Vec operator -(Vec a, Vec b) => new(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
        public static Vec operator *(Vec a, double s) => new(a.X * s, a.Y * s, a.Z * s);
        public static Vec operator *(Vec a, Vec b) => new(a.X * b.X, a.Y * b.Y, a.Z * b.Z);
        public static Vec operator /(Vec a, double s) => new(a.X / s, a.Y / s, a.Z / s);
        public static double Dot(Vec a, Vec b) => a.X * b.X + a.Y * b.Y + a.Z * b.Z;
        public static Vec Cross(Vec a, Vec b) => new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X);
        public double Length => Math.Sqrt(Dot(this, this));
        public Vec Normalized => this * (1.0 / Length);
    }

    private sealed class Material
    {
        public Vec Colour, Other;
        public double Scale; // 0 for a plain material; the width of a checker's squares otherwise
        public double Diffuse, Specular, Reflect;
        public int Shininess;
    }

    private sealed class Shape
    {
        public bool IsSphere;
        public Vec Point;      // a sphere's centre, a point on a plane
        public Vec Normal;     // a plane's normal, unit length
        public double Radius;
        public Material Material = null!;
    }

    private sealed class Light
    {
        public Vec Position, Colour;
    }

    private static int width = 320, height = 240, samples = 1, depth = 3;
    private static Vec eye, target = new(0, 0, 1), up = new(0, 1, 0);
    private static double view = 0.5;
    private static Vec background, ambient;
    private static readonly List<Light> lights = [];
    private static readonly List<Shape> shapes = [];
    private static readonly Dictionary<string, Material> materials = [];

    public static int Run(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: raytracer <scene.txt> <output.ppm>");
            return 1;
        }
        Load(args[0]);

        Vec forward = (target - eye).Normalized;
        Vec right = Vec.Cross(up, forward).Normalized;
        Vec upward = Vec.Cross(forward, right);
        double aspect = (double)width / height;

        byte[] pixels = new byte[width * height * 3];
        long checksum = 0;
        int at = 0;
        for (int py = 0; py < height; py++)
        {
            for (int px = 0; px < width; px++)
            {
                Vec colour = new(0, 0, 0);
                for (int sy = 0; sy < samples; sy++)
                {
                    for (int sx = 0; sx < samples; sx++)
                    {
                        double u = (px + (sx + 0.5) / samples) / width * 2 - 1;
                        double v = 1 - (py + (sy + 0.5) / samples) / height * 2;
                        Vec direction = (forward + right * (u * aspect * view) + upward * (v * view)).Normalized;
                        colour = colour + Trace(eye, direction, depth);
                    }
                }
                colour = colour / (samples * samples);
                foreach (double channel in (ReadOnlySpan<double>)[colour.X, colour.Y, colour.Z])
                {
                    double c = channel < 0 ? 0 : channel > 1 ? 1 : channel;
                    int value = (int)Math.Floor(Math.Sqrt(c) * 255 + 0.5);
                    pixels[at++] = (byte)value;
                    checksum += value;
                }
            }
        }

        using (FileStream file = File.Create(args[1]))
        {
            file.Write(Encoding.ASCII.GetBytes($"P6\n{width} {height}\n255\n"));
            file.Write(pixels);
        }
        Console.WriteLine($"Checksum: {checksum}");
        return 0;
    }

    private static Vec Trace(Vec origin, Vec direction, int remaining)
    {
        double nearest = Far;
        Shape? hit = null;
        foreach (Shape shape in shapes)
        {
            double t = Intersect(shape, origin, direction);
            if (t > Epsilon && t < nearest)
            {
                nearest = t;
                hit = shape;
            }
        }
        if (hit == null)
            return background;

        Vec point = origin + direction * nearest;
        Vec normal = hit.IsSphere ? (point - hit.Point) / hit.Radius : hit.Normal;
        if (Vec.Dot(normal, direction) > 0)
            normal = normal * -1;
        Material material = hit.Material;
        Vec colour = material.Colour;
        if (material.Scale > 0)
        {
            double k = Math.Floor(point.X / material.Scale) + Math.Floor(point.Z / material.Scale);
            if (k - 2 * Math.Floor(k / 2) != 0)
                colour = material.Other;
        }

        Vec result = ambient * colour;
        Vec lifted = point + normal * Epsilon;
        foreach (Light light in lights)
        {
            Vec toLight = light.Position - point;
            double distance = toLight.Length;
            Vec lightDirection = toLight.Normalized;
            if (Shadowed(lifted, lightDirection, distance))
                continue;
            double diffuse = Vec.Dot(normal, lightDirection);
            if (diffuse > 0)
            {
                result = result + colour * light.Colour * (material.Diffuse * diffuse);
                Vec reflected = normal * (2 * diffuse) - lightDirection;
                double specular = -Vec.Dot(reflected, direction);
                if (specular > 0)
                {
                    double power = 1;
                    for (int i = 0; i < material.Shininess; i++)
                        power = power * specular;
                    result = result + light.Colour * (material.Specular * power);
                }
            }
        }

        if (remaining > 0 && material.Reflect > 0)
        {
            Vec bounced = direction - normal * (2 * Vec.Dot(direction, normal));
            Vec mirrored = Trace(lifted, bounced, remaining - 1);
            result = result * (1 - material.Reflect) + mirrored * material.Reflect;
        }
        return result;
    }

    private static bool Shadowed(Vec origin, Vec direction, double distance)
    {
        foreach (Shape shape in shapes)
        {
            double t = Intersect(shape, origin, direction);
            if (t > Epsilon && t < distance)
                return true;
        }
        return false;
    }

    // The distance along the ray to the shape, or -1 when the ray misses it.
    private static double Intersect(Shape shape, Vec origin, Vec direction)
    {
        if (shape.IsSphere)
        {
            Vec offset = origin - shape.Point;
            double b = Vec.Dot(offset, direction);
            double c = Vec.Dot(offset, offset) - shape.Radius * shape.Radius;
            double discriminant = b * b - c;
            if (discriminant < 0)
                return -1;
            double root = Math.Sqrt(discriminant);
            double t = -b - root;
            if (t > Epsilon)
                return t;
            t = -b + root;
            return t > Epsilon ? t : -1;
        }
        double facing = Vec.Dot(shape.Normal, direction);
        if (Math.Abs(facing) < 1e-9)
            return -1;
        double distance = Vec.Dot(shape.Point - origin, shape.Normal) / facing;
        return distance > Epsilon ? distance : -1;
    }

    private static void Load(string path)
    {
        foreach (string raw in File.ReadAllLines(path))
        {
            int comment = raw.IndexOf('#');
            string line = comment >= 0 ? raw[..comment] : raw;
            string[] words = line.Split([' ', '\t'], StringSplitOptions.RemoveEmptyEntries);
            if (words.Length == 0)
                continue;
            double N(int index) => double.Parse(words[index], CultureInfo.InvariantCulture);
            Vec V(int index) => new(N(index), N(index + 1), N(index + 2));
            switch (words[0])
            {
                case "size": width = int.Parse(words[1], CultureInfo.InvariantCulture); height = int.Parse(words[2], CultureInfo.InvariantCulture); break;
                case "samples": samples = int.Parse(words[1], CultureInfo.InvariantCulture); break;
                case "depth": depth = int.Parse(words[1], CultureInfo.InvariantCulture); break;
                case "camera": eye = V(1); target = V(4); up = V(7); view = N(10); break;
                case "background": background = V(1); break;
                case "ambient": ambient = V(1); break;
                case "light": lights.Add(new Light { Position = V(1), Colour = V(4) }); break;
                case "material":
                    materials[words[1]] = new Material { Colour = V(2), Other = V(2), Diffuse = N(5), Specular = N(6), Shininess = int.Parse(words[7], CultureInfo.InvariantCulture), Reflect = N(8) };
                    break;
                case "checker":
                    materials[words[1]] = new Material { Colour = V(2), Other = V(5), Scale = N(8), Diffuse = N(9), Specular = N(10), Shininess = int.Parse(words[11], CultureInfo.InvariantCulture), Reflect = N(12) };
                    break;
                case "sphere": shapes.Add(new Shape { IsSphere = true, Point = V(1), Radius = N(4), Material = materials[words[5]] }); break;
                case "plane": shapes.Add(new Shape { Point = V(1), Normal = V(4).Normalized, Material = materials[words[7]] }); break;
                default: throw new FormatException($"Unknown directive '{words[0]}'.");
            }
        }
    }
}

Environment.ExitCode = RayTracer.Run(Arguments);
