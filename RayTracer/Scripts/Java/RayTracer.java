// Ray tracer benchmark, Java - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
// javac RayTracer.java
// java -cp . RayTracer <scene.txt> <output.ppm>
// Java 17 and later evaluate every floating-point operation strictly (JEP 306), so nothing is fused.
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class RayTracer {
    record Vec(double x, double y, double z) {
        Vec add(Vec b) { return new Vec(x + b.x, y + b.y, z + b.z); }
        Vec sub(Vec b) { return new Vec(x - b.x, y - b.y, z - b.z); }
        Vec scale(double s) { return new Vec(x * s, y * s, z * s); }
        Vec mul(Vec b) { return new Vec(x * b.x, y * b.y, z * b.z); }
        Vec div(double s) { return new Vec(x / s, y / s, z / s); }
        static double dot(Vec a, Vec b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
        static Vec cross(Vec a, Vec b) { return new Vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x); }
        double length() { return Math.sqrt(dot(this, this)); }
        Vec normalized() { return scale(1.0 / length()); }
    }

    static final class Material {
        Vec colour, other;
        double scale, diffuse, specular, reflect;
        int shininess;
    }

    static final class Shape {
        boolean isSphere;
        Vec point, normal;
        double radius;
        Material material;
    }

    record Light(Vec position, Vec colour) {}

    static final double EPSILON = 1e-4;
    static final double FAR = 1e30;

    static int width = 320, height = 240, samples = 1, depth = 3;
    static Vec eye = new Vec(0, 0, 0), target = new Vec(0, 0, 1), up = new Vec(0, 1, 0);
    static double view = 0.5;
    static Vec background = new Vec(0, 0, 0), ambient = new Vec(0, 0, 0);
    static final List<Light> lights = new ArrayList<>();
    static final List<Shape> shapes = new ArrayList<>();
    static final Map<String, Material> materials = new HashMap<>();
    static Shape[] shapeArray;

    // The distance along the ray to the shape, or -1 when the ray misses it.
    static double intersect(Shape shape, Vec origin, Vec direction) {
        if (shape.isSphere) {
            Vec offset = origin.sub(shape.point);
            double b = Vec.dot(offset, direction);
            double c = Vec.dot(offset, offset) - shape.radius * shape.radius;
            double discriminant = b * b - c;
            if (discriminant < 0)
                return -1;
            double root = Math.sqrt(discriminant);
            double t = -b - root;
            if (t > EPSILON)
                return t;
            t = -b + root;
            return t > EPSILON ? t : -1;
        }
        double facing = Vec.dot(shape.normal, direction);
        if (Math.abs(facing) < 1e-9)
            return -1;
        double distance = Vec.dot(shape.point.sub(origin), shape.normal) / facing;
        return distance > EPSILON ? distance : -1;
    }

    static boolean shadowed(Vec origin, Vec direction, double distance) {
        for (Shape shape : shapeArray) {
            double t = intersect(shape, origin, direction);
            if (t > EPSILON && t < distance)
                return true;
        }
        return false;
    }

    static Vec trace(Vec origin, Vec direction, int remaining) {
        double nearest = FAR;
        Shape hit = null;
        for (Shape shape : shapeArray) {
            double t = intersect(shape, origin, direction);
            if (t > EPSILON && t < nearest) {
                nearest = t;
                hit = shape;
            }
        }
        if (hit == null)
            return background;

        Vec point = origin.add(direction.scale(nearest));
        Vec normal = hit.isSphere ? point.sub(hit.point).div(hit.radius) : hit.normal;
        if (Vec.dot(normal, direction) > 0)
            normal = normal.scale(-1);
        Material material = hit.material;
        Vec colour = material.colour;
        if (material.scale > 0) {
            double k = Math.floor(point.x() / material.scale) + Math.floor(point.z() / material.scale);
            if (k - 2 * Math.floor(k / 2) != 0)
                colour = material.other;
        }

        Vec result = ambient.mul(colour);
        Vec lifted = point.add(normal.scale(EPSILON));
        for (Light light : lights) {
            Vec toLight = light.position().sub(point);
            double distance = toLight.length();
            Vec lightDirection = toLight.normalized();
            if (shadowed(lifted, lightDirection, distance))
                continue;
            double diffuse = Vec.dot(normal, lightDirection);
            if (diffuse > 0) {
                result = result.add(colour.mul(light.colour()).scale(material.diffuse * diffuse));
                Vec reflected = normal.scale(2 * diffuse).sub(lightDirection);
                double specular = -Vec.dot(reflected, direction);
                if (specular > 0) {
                    double power = 1;
                    for (int i = 0; i < material.shininess; i++)
                        power = power * specular;
                    result = result.add(light.colour().scale(material.specular * power));
                }
            }
        }

        if (remaining > 0 && material.reflect > 0) {
            Vec bounced = direction.sub(normal.scale(2 * Vec.dot(direction, normal)));
            Vec mirrored = trace(lifted, bounced, remaining - 1);
            result = result.scale(1 - material.reflect).add(mirrored.scale(material.reflect));
        }
        return result;
    }

    static void load(String path) throws IOException {
        for (String raw : Files.readAllLines(Path.of(path), StandardCharsets.UTF_8)) {
            int comment = raw.indexOf('#');
            String line = (comment >= 0 ? raw.substring(0, comment) : raw).trim();
            if (line.isEmpty())
                continue;
            String[] w = line.split("\\s+");
            switch (w[0]) {
                case "size" -> { width = Integer.parseInt(w[1]); height = Integer.parseInt(w[2]); }
                case "samples" -> samples = Integer.parseInt(w[1]);
                case "depth" -> depth = Integer.parseInt(w[1]);
                case "camera" -> { eye = v(w, 1); target = v(w, 4); up = v(w, 7); view = n(w, 10); }
                case "background" -> background = v(w, 1);
                case "ambient" -> ambient = v(w, 1);
                case "light" -> lights.add(new Light(v(w, 1), v(w, 4)));
                case "material" -> {
                    Material m = new Material();
                    m.colour = v(w, 2); m.other = v(w, 2); m.diffuse = n(w, 5); m.specular = n(w, 6); m.shininess = Integer.parseInt(w[7]); m.reflect = n(w, 8);
                    materials.put(w[1], m);
                }
                case "checker" -> {
                    Material m = new Material();
                    m.colour = v(w, 2); m.other = v(w, 5); m.scale = n(w, 8); m.diffuse = n(w, 9); m.specular = n(w, 10); m.shininess = Integer.parseInt(w[11]); m.reflect = n(w, 12);
                    materials.put(w[1], m);
                }
                case "sphere" -> {
                    Shape s = new Shape();
                    s.isSphere = true; s.point = v(w, 1); s.radius = n(w, 4); s.material = materials.get(w[5]);
                    shapes.add(s);
                }
                case "plane" -> {
                    Shape s = new Shape();
                    s.point = v(w, 1); s.normal = v(w, 4).normalized(); s.material = materials.get(w[7]);
                    shapes.add(s);
                }
                default -> throw new IllegalArgumentException("Unknown directive '" + w[0] + "'.");
            }
        }
        shapeArray = shapes.toArray(new Shape[0]);
    }

    static double n(String[] w, int i) { return Double.parseDouble(w[i]); }
    static Vec v(String[] w, int i) { return new Vec(n(w, i), n(w, i + 1), n(w, i + 2)); }

    public static void main(String[] args) throws IOException {
        if (args.length < 2) {
            System.err.println("Usage: raytracer <scene.txt> <output.ppm>");
            System.exit(1);
        }
        load(args[0]);

        Vec forward = target.sub(eye).normalized();
        Vec right = Vec.cross(up, forward).normalized();
        Vec upward = Vec.cross(forward, right);
        double aspect = (double) width / height;

        byte[] pixels = new byte[width * height * 3];
        long checksum = 0;
        int at = 0;
        for (int py = 0; py < height; py++) {
            for (int px = 0; px < width; px++) {
                Vec colour = new Vec(0, 0, 0);
                for (int sy = 0; sy < samples; sy++) {
                    for (int sx = 0; sx < samples; sx++) {
                        double u = (px + (sx + 0.5) / samples) / width * 2 - 1;
                        double v = 1 - (py + (sy + 0.5) / samples) / height * 2;
                        Vec direction = forward.add(right.scale(u * aspect * view)).add(upward.scale(v * view)).normalized();
                        colour = colour.add(trace(eye, direction, depth));
                    }
                }
                colour = colour.div(samples * samples);
                for (double channel : new double[] { colour.x(), colour.y(), colour.z() }) {
                    double c = channel < 0 ? 0 : channel > 1 ? 1 : channel;
                    int value = (int) Math.floor(Math.sqrt(c) * 255 + 0.5);
                    pixels[at++] = (byte) value;
                    checksum += value;
                }
            }
        }

        try (OutputStream out = new BufferedOutputStream(new FileOutputStream(args[1]))) {
            out.write(("P6\n" + width + " " + height + "\n255\n").getBytes(StandardCharsets.US_ASCII));
            out.write(pixels);
        }
        System.out.println("Checksum: " + checksum);
    }
}
