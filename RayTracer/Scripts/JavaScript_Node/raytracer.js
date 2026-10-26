// Ray tracer benchmark, JavaScript (Node) - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
// node raytracer.js <scene.txt> <output.ppm>
'use strict';
const fs = require('fs');

const vec = (x, y, z) => ({ x, y, z });
const add = (a, b) => vec(a.x + b.x, a.y + b.y, a.z + b.z);
const sub = (a, b) => vec(a.x - b.x, a.y - b.y, a.z - b.z);
const scale = (a, s) => vec(a.x * s, a.y * s, a.z * s);
const mul = (a, b) => vec(a.x * b.x, a.y * b.y, a.z * b.z);
const div = (a, s) => vec(a.x / s, a.y / s, a.z / s);
const dot = (a, b) => a.x * b.x + a.y * b.y + a.z * b.z;
const cross = (a, b) => vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
const length = (v) => Math.sqrt(dot(v, v));
const normalize = (v) => scale(v, 1.0 / length(v));

const EPSILON = 1e-4;
const FAR = 1e30;

let width = 320, height = 240, samples = 1, depth = 3;
let eye = vec(0, 0, 0), target = vec(0, 0, 1), up = vec(0, 1, 0), view = 0.5;
let background = vec(0, 0, 0), ambient = vec(0, 0, 0);
const lights = [];
const shapes = [];
const materials = new Map();

// The distance along the ray to the shape, or -1 when the ray misses it.
function intersect(shape, origin, direction) {
    if (shape.isSphere) {
        const offset = sub(origin, shape.point);
        const b = dot(offset, direction);
        const c = dot(offset, offset) - shape.radius * shape.radius;
        const discriminant = b * b - c;
        if (discriminant < 0)
            return -1;
        const root = Math.sqrt(discriminant);
        let t = -b - root;
        if (t > EPSILON)
            return t;
        t = -b + root;
        return t > EPSILON ? t : -1;
    }
    const facing = dot(shape.normal, direction);
    if (Math.abs(facing) < 1e-9)
        return -1;
    const distance = dot(sub(shape.point, origin), shape.normal) / facing;
    return distance > EPSILON ? distance : -1;
}

function shadowed(origin, direction, distance) {
    for (const shape of shapes) {
        const t = intersect(shape, origin, direction);
        if (t > EPSILON && t < distance)
            return true;
    }
    return false;
}

function trace(origin, direction, remaining) {
    let nearest = FAR;
    let hit = null;
    for (const shape of shapes) {
        const t = intersect(shape, origin, direction);
        if (t > EPSILON && t < nearest) {
            nearest = t;
            hit = shape;
        }
    }
    if (hit === null)
        return background;

    const point = add(origin, scale(direction, nearest));
    let normal = hit.isSphere ? div(sub(point, hit.point), hit.radius) : hit.normal;
    if (dot(normal, direction) > 0)
        normal = scale(normal, -1);
    const material = hit.material;
    let colour = material.colour;
    if (material.scale > 0) {
        const k = Math.floor(point.x / material.scale) + Math.floor(point.z / material.scale);
        if (k - 2 * Math.floor(k / 2) !== 0)
            colour = material.other;
    }

    let result = mul(ambient, colour);
    const lifted = add(point, scale(normal, EPSILON));
    for (const light of lights) {
        const toLight = sub(light.position, point);
        const distance = length(toLight);
        const lightDirection = normalize(toLight);
        if (shadowed(lifted, lightDirection, distance))
            continue;
        const diffuse = dot(normal, lightDirection);
        if (diffuse > 0) {
            result = add(result, scale(mul(colour, light.colour), material.diffuse * diffuse));
            const reflected = sub(scale(normal, 2 * diffuse), lightDirection);
            const specular = -dot(reflected, direction);
            if (specular > 0) {
                let power = 1;
                for (let i = 0; i < material.shininess; i++)
                    power = power * specular;
                result = add(result, scale(light.colour, material.specular * power));
            }
        }
    }

    if (remaining > 0 && material.reflect > 0) {
        const bounced = sub(direction, scale(normal, 2 * dot(direction, normal)));
        const mirrored = trace(lifted, bounced, remaining - 1);
        result = add(scale(result, 1 - material.reflect), scale(mirrored, material.reflect));
    }
    return result;
}

function load(path) {
    for (const raw of fs.readFileSync(path, 'utf8').split('\n')) {
        const comment = raw.indexOf('#');
        const line = comment >= 0 ? raw.slice(0, comment) : raw;
        const w = line.split(/\s+/).filter((word) => word.length > 0);
        if (w.length === 0)
            continue;
        const n = (i) => Number(w[i]);
        const v = (i) => vec(n(i), n(i + 1), n(i + 2));
        switch (w[0]) {
            case 'size': width = parseInt(w[1], 10); height = parseInt(w[2], 10); break;
            case 'samples': samples = parseInt(w[1], 10); break;
            case 'depth': depth = parseInt(w[1], 10); break;
            case 'camera': eye = v(1); target = v(4); up = v(7); view = n(10); break;
            case 'background': background = v(1); break;
            case 'ambient': ambient = v(1); break;
            case 'light': lights.push({ position: v(1), colour: v(4) }); break;
            case 'material':
                materials.set(w[1], { colour: v(2), other: v(2), scale: 0, diffuse: n(5), specular: n(6), shininess: parseInt(w[7], 10), reflect: n(8) });
                break;
            case 'checker':
                materials.set(w[1], { colour: v(2), other: v(5), scale: n(8), diffuse: n(9), specular: n(10), shininess: parseInt(w[11], 10), reflect: n(12) });
                break;
            case 'sphere': shapes.push({ isSphere: true, point: v(1), normal: vec(0, 0, 0), radius: n(4), material: materials.get(w[5]) }); break;
            case 'plane': shapes.push({ isSphere: false, point: v(1), normal: normalize(v(4)), radius: 0, material: materials.get(w[7]) }); break;
            default: throw new Error(`Unknown directive '${w[0]}'.`);
        }
    }
}

function main() {
    if (process.argv.length < 4) {
        console.error('Usage: raytracer <scene.txt> <output.ppm>');
        process.exit(1);
    }
    load(process.argv[2]);

    const forward = normalize(sub(target, eye));
    const right = normalize(cross(up, forward));
    const upward = cross(forward, right);
    const aspect = width / height;

    const pixels = Buffer.alloc(width * height * 3);
    let checksum = 0;
    let at = 0;
    for (let py = 0; py < height; py++) {
        for (let px = 0; px < width; px++) {
            let colour = vec(0, 0, 0);
            for (let sy = 0; sy < samples; sy++) {
                for (let sx = 0; sx < samples; sx++) {
                    const u = (px + (sx + 0.5) / samples) / width * 2 - 1;
                    const v = 1 - (py + (sy + 0.5) / samples) / height * 2;
                    const direction = normalize(add(add(forward, scale(right, u * aspect * view)), scale(upward, v * view)));
                    colour = add(colour, trace(eye, direction, depth));
                }
            }
            colour = div(colour, samples * samples);
            for (const channel of [colour.x, colour.y, colour.z]) {
                const c = channel < 0 ? 0 : channel > 1 ? 1 : channel;
                const value = Math.floor(Math.sqrt(c) * 255 + 0.5);
                pixels[at++] = value;
                checksum += value;
            }
        }
    }

    fs.writeFileSync(process.argv[3], Buffer.concat([Buffer.from(`P6\n${width} ${height}\n255\n`, 'ascii'), pixels]));
    console.log(`Checksum: ${checksum}`);
}

main();
