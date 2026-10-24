% Ray tracer benchmark, GNU Octave - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
% octave-cli raytracer.m <scene.txt> <output.ppm>
% A vector is a 1x3 row. Element-wise +, -, .*, ./ and scaling round each element as the reference does; a sum of products is
% written out (vdot) rather than left to dot() or a matrix product, whose order and fusing are the library's choice.
1;

function d = vdot(a, b)
    d = a(1) * b(1) + a(2) * b(2) + a(3) * b(3);
end

function c = vcross(a, b)
    c = [a(2) * b(3) - a(3) * b(2), a(3) * b(1) - a(1) * b(3), a(1) * b(2) - a(2) * b(1)];
end

function n = vnormalize(v)
    n = v .* (1.0 / sqrt(vdot(v, v)));
end

% The distance along the ray to the shape, or -1 when the ray misses it.
function t = hit_distance(shape, origin, direction)
    epsilon = 1e-4;
    if shape.sphere
        offset = origin - shape.point;
        b = vdot(offset, direction);
        c = vdot(offset, offset) - shape.radius * shape.radius;
        discriminant = b * b - c;
        if discriminant < 0
            t = -1;
            return;
        end
        root = sqrt(discriminant);
        t = -b - root;
        if t > epsilon
            return;
        end
        t = -b + root;
        if !(t > epsilon)
            t = -1;
        end
    else
        facing = vdot(shape.normal, direction);
        if abs(facing) < 1e-9
            t = -1;
            return;
        end
        t = vdot(shape.point - origin, shape.normal) / facing;
        if !(t > epsilon)
            t = -1;
        end
    end
end

function blocked = shadowed(shapes, origin, direction, distance)
    epsilon = 1e-4;
    blocked = false;
    for i = 1:numel(shapes)
        t = hit_distance(shapes{i}, origin, direction);
        if t > epsilon && t < distance
            blocked = true;
            return;
        end
    end
end

function colour = trace_ray(scene, origin, direction, remaining)
    epsilon = 1e-4;
    nearest = 1e30;
    hit = 0;
    for i = 1:numel(scene.shapes)
        t = hit_distance(scene.shapes{i}, origin, direction);
        if t > epsilon && t < nearest
            nearest = t;
            hit = i;
        end
    end
    if hit == 0
        colour = scene.background;
        return;
    end
    shape = scene.shapes{hit};

    point = origin + direction .* nearest;
    if shape.sphere
        normal = (point - shape.point) ./ shape.radius;
    else
        normal = shape.normal;
    end
    if vdot(normal, direction) > 0
        normal = normal .* -1;
    end
    material = shape.material;
    base = material.colour;
    if material.scale > 0
        k = floor(point(1) / material.scale) + floor(point(3) / material.scale);
        if k - 2 * floor(k / 2) != 0
            base = material.other;
        end
    end

    result = scene.ambient .* base;
    lifted = point + normal .* epsilon;
    for i = 1:numel(scene.lights)
        light = scene.lights{i};
        to_light = light.position - point;
        distance = sqrt(vdot(to_light, to_light));
        light_direction = vnormalize(to_light);
        if shadowed(scene.shapes, lifted, light_direction, distance)
            continue;
        end
        diffuse = vdot(normal, light_direction);
        if diffuse > 0
            result = result + (base .* light.colour) .* (material.diffuse * diffuse);
            reflected = normal .* (2 * diffuse) - light_direction;
            specular = -vdot(reflected, direction);
            if specular > 0
                power = 1;
                for j = 1:material.shininess
                    power = power * specular;
                end
                result = result + light.colour .* (material.specular * power);
            end
        end
    end

    if remaining > 0 && material.reflect > 0
        bounced = direction - normal .* (2 * vdot(direction, normal));
        mirrored = trace_ray(scene, lifted, bounced, remaining - 1);
        result = result .* (1 - material.reflect) + mirrored .* material.reflect;
    end
    colour = result;
end

function scene = load_scene(path)
    scene = struct('width', 320, 'height', 240, 'samples', 1, 'depth', 3, 'eye', [0 0 0], 'target', [0 0 1], 'up', [0 1 0], ...
                   'view', 0.5, 'background', [0 0 0], 'ambient', [0 0 0]);
    scene.lights = {};
    scene.shapes = {};
    materials = struct();
    fid = fopen(path, 'r');
    while true
        raw = fgetl(fid);
        if !ischar(raw)
            break;
        end
        at = index(raw, '#');
        if at > 0
            raw = raw(1:at - 1);
        end
        w = strsplit(strtrim(raw));
        if isempty(w) || isempty(w{1})
            continue;
        end
        n = @(i) str2double(w{i + 1});
        v = @(i) [n(i), n(i + 1), n(i + 2)];
        switch w{1}
            case 'size'
                scene.width = n(1); scene.height = n(2);
            case 'samples'
                scene.samples = n(1);
            case 'depth'
                scene.depth = n(1);
            case 'camera'
                scene.eye = v(1); scene.target = v(4); scene.up = v(7); scene.view = n(10);
            case 'background'
                scene.background = v(1);
            case 'ambient'
                scene.ambient = v(1);
            case 'light'
                scene.lights{end + 1} = struct('position', v(1), 'colour', v(4));
            case 'material'
                materials.(w{2}) = struct('colour', v(2), 'other', v(2), 'scale', 0, 'diffuse', n(5), 'specular', n(6), 'shininess', n(7), 'reflect', n(8));
            case 'checker'
                materials.(w{2}) = struct('colour', v(2), 'other', v(5), 'scale', n(8), 'diffuse', n(9), 'specular', n(10), 'shininess', n(11), 'reflect', n(12));
            case 'sphere'
                scene.shapes{end + 1} = struct('sphere', true, 'point', v(1), 'normal', [0 0 0], 'radius', n(4), 'material', materials.(w{6}));
            case 'plane'
                scene.shapes{end + 1} = struct('sphere', false, 'point', v(1), 'normal', vnormalize(v(4)), 'radius', 0, 'material', materials.(w{8}));
            otherwise
                error('Unknown directive ''%s''.', w{1});
        end
    end
    fclose(fid);
end

args = argv();
if numel(args) < 2
    fprintf(stderr, 'Usage: raytracer <scene.txt> <output.ppm>\n');
    exit(1);
end
scene = load_scene(args{1});
width = scene.width; height = scene.height; samples = scene.samples; view = scene.view;

forward = vnormalize(scene.target - scene.eye);
right = vnormalize(vcross(scene.up, forward));
upward = vcross(forward, right);
aspect = width / height;

pixels = zeros(1, width * height * 3, 'uint8');
checksum = 0;
at = 1;
for py = 0:(height - 1)
    for px = 0:(width - 1)
        colour = [0 0 0];
        for sy = 0:(samples - 1)
            for sx = 0:(samples - 1)
                u = (px + (sx + 0.5) / samples) / width * 2 - 1;
                v = 1 - (py + (sy + 0.5) / samples) / height * 2;
                direction = vnormalize(forward + right .* (u * aspect * view) + upward .* (v * view));
                colour = colour + trace_ray(scene, scene.eye, direction, scene.depth);
            end
        end
        colour = colour ./ (samples * samples);
        for channel = colour
            c = channel;
            if c < 0
                c = 0;
            elseif c > 1
                c = 1;
            end
            value = floor(sqrt(c) * 255 + 0.5);
            pixels(at) = value;
            at = at + 1;
            checksum = checksum + value;
        end
    end
end

fid = fopen(args{2}, 'wb');
fprintf(fid, 'P6\n%d %d\n255\n', width, height);
fwrite(fid, pixels, 'uint8');
fclose(fid);
printf('Checksum: %d\n', checksum);
