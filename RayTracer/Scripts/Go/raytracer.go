// Ray tracer benchmark, Go - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
// go run raytracer.go <scene.txt> <output.ppm>
// Built for the default GOAMD64=v1, which has no fused multiply-add for the compiler to contract into.
package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
)

type Vec struct{ X, Y, Z float64 }

func add(a, b Vec) Vec        { return Vec{a.X + b.X, a.Y + b.Y, a.Z + b.Z} }
func sub(a, b Vec) Vec        { return Vec{a.X - b.X, a.Y - b.Y, a.Z - b.Z} }
func scale(a Vec, s float64) Vec { return Vec{a.X * s, a.Y * s, a.Z * s} }
func mul(a, b Vec) Vec        { return Vec{a.X * b.X, a.Y * b.Y, a.Z * b.Z} }
func div(a Vec, s float64) Vec { return Vec{a.X / s, a.Y / s, a.Z / s} }
func dot(a, b Vec) float64    { return a.X*b.X + a.Y*b.Y + a.Z*b.Z }
func cross(a, b Vec) Vec {
	return Vec{a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X}
}
func length(v Vec) float64  { return math.Sqrt(dot(v, v)) }
func normalize(v Vec) Vec   { return scale(v, 1.0/length(v)) }

type Material struct {
	Colour, Other                      Vec
	Scale, Diffuse, Specular, Reflect  float64
	Shininess                          int
}

type Shape struct {
	IsSphere      bool
	Point, Normal Vec
	Radius        float64
	Material      *Material
}

type Light struct{ Position, Colour Vec }

const Epsilon = 1e-4
const Far = 1e30

var (
	width, height, samples, depth = 320, 240, 1, 3
	eye                           = Vec{0, 0, 0}
	target                        = Vec{0, 0, 1}
	up                            = Vec{0, 1, 0}
	view                          = 0.5
	background, ambient           Vec
	lights                        []Light
	shapes                        []Shape
	materials                     = map[string]*Material{}
)

// The distance along the ray to the shape, or -1 when the ray misses it.
func intersect(shape *Shape, origin, direction Vec) float64 {
	if shape.IsSphere {
		offset := sub(origin, shape.Point)
		b := dot(offset, direction)
		c := dot(offset, offset) - shape.Radius*shape.Radius
		discriminant := b*b - c
		if discriminant < 0 {
			return -1
		}
		root := math.Sqrt(discriminant)
		t := -b - root
		if t > Epsilon {
			return t
		}
		t = -b + root
		if t > Epsilon {
			return t
		}
		return -1
	}
	facing := dot(shape.Normal, direction)
	if math.Abs(facing) < 1e-9 {
		return -1
	}
	distance := dot(sub(shape.Point, origin), shape.Normal) / facing
	if distance > Epsilon {
		return distance
	}
	return -1
}

func shadowed(origin, direction Vec, distance float64) bool {
	for i := range shapes {
		t := intersect(&shapes[i], origin, direction)
		if t > Epsilon && t < distance {
			return true
		}
	}
	return false
}

func trace(origin, direction Vec, remaining int) Vec {
	nearest := Far
	var hit *Shape
	for i := range shapes {
		t := intersect(&shapes[i], origin, direction)
		if t > Epsilon && t < nearest {
			nearest = t
			hit = &shapes[i]
		}
	}
	if hit == nil {
		return background
	}

	point := add(origin, scale(direction, nearest))
	var normal Vec
	if hit.IsSphere {
		normal = div(sub(point, hit.Point), hit.Radius)
	} else {
		normal = hit.Normal
	}
	if dot(normal, direction) > 0 {
		normal = scale(normal, -1)
	}
	material := hit.Material
	colour := material.Colour
	if material.Scale > 0 {
		k := math.Floor(point.X/material.Scale) + math.Floor(point.Z/material.Scale)
		if k-2*math.Floor(k/2) != 0 {
			colour = material.Other
		}
	}

	result := mul(ambient, colour)
	lifted := add(point, scale(normal, Epsilon))
	for _, light := range lights {
		toLight := sub(light.Position, point)
		distance := length(toLight)
		lightDirection := normalize(toLight)
		if shadowed(lifted, lightDirection, distance) {
			continue
		}
		diffuse := dot(normal, lightDirection)
		if diffuse > 0 {
			result = add(result, scale(mul(colour, light.Colour), material.Diffuse*diffuse))
			reflected := sub(scale(normal, 2*diffuse), lightDirection)
			specular := -dot(reflected, direction)
			if specular > 0 {
				power := 1.0
				for i := 0; i < material.Shininess; i++ {
					power = power * specular
				}
				result = add(result, scale(light.Colour, material.Specular*power))
			}
		}
	}

	if remaining > 0 && material.Reflect > 0 {
		bounced := sub(direction, scale(normal, 2*dot(direction, normal)))
		mirrored := trace(lifted, bounced, remaining-1)
		result = add(scale(result, 1-material.Reflect), scale(mirrored, material.Reflect))
	}
	return result
}

func load(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	for _, raw := range strings.Split(string(data), "\n") {
		line := raw
		if at := strings.IndexByte(line, '#'); at >= 0 {
			line = line[:at]
		}
		w := strings.Fields(line)
		if len(w) == 0 {
			continue
		}
		n := func(i int) float64 {
			value, err := strconv.ParseFloat(w[i], 64)
			if err != nil {
				panic(err)
			}
			return value
		}
		v := func(i int) Vec { return Vec{n(i), n(i + 1), n(i + 2)} }
		integer := func(i int) int {
			value, err := strconv.Atoi(w[i])
			if err != nil {
				panic(err)
			}
			return value
		}
		switch w[0] {
		case "size":
			width, height = integer(1), integer(2)
		case "samples":
			samples = integer(1)
		case "depth":
			depth = integer(1)
		case "camera":
			eye, target, up, view = v(1), v(4), v(7), n(10)
		case "background":
			background = v(1)
		case "ambient":
			ambient = v(1)
		case "light":
			lights = append(lights, Light{v(1), v(4)})
		case "material":
			materials[w[1]] = &Material{Colour: v(2), Other: v(2), Diffuse: n(5), Specular: n(6), Shininess: integer(7), Reflect: n(8)}
		case "checker":
			materials[w[1]] = &Material{Colour: v(2), Other: v(5), Scale: n(8), Diffuse: n(9), Specular: n(10), Shininess: integer(11), Reflect: n(12)}
		case "sphere":
			shapes = append(shapes, Shape{IsSphere: true, Point: v(1), Radius: n(4), Material: materials[w[5]]})
		case "plane":
			shapes = append(shapes, Shape{Point: v(1), Normal: normalize(v(4)), Material: materials[w[7]]})
		default:
			panic("Unknown directive '" + w[0] + "'.")
		}
	}
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "Usage: raytracer <scene.txt> <output.ppm>")
		os.Exit(1)
	}
	load(os.Args[1])

	forward := normalize(sub(target, eye))
	right := normalize(cross(up, forward))
	upward := cross(forward, right)
	aspect := float64(width) / float64(height)

	pixels := make([]byte, width*height*3)
	var checksum int64
	at := 0
	for py := 0; py < height; py++ {
		for px := 0; px < width; px++ {
			colour := Vec{0, 0, 0}
			for sy := 0; sy < samples; sy++ {
				for sx := 0; sx < samples; sx++ {
					u := (float64(px)+(float64(sx)+0.5)/float64(samples))/float64(width)*2 - 1
					v := 1 - (float64(py)+(float64(sy)+0.5)/float64(samples))/float64(height)*2
					direction := normalize(add(add(forward, scale(right, u*aspect*view)), scale(upward, v*view)))
					colour = add(colour, trace(eye, direction, depth))
				}
			}
			colour = div(colour, float64(samples*samples))
			for _, channel := range [3]float64{colour.X, colour.Y, colour.Z} {
				c := channel
				if c < 0 {
					c = 0
				} else if c > 1 {
					c = 1
				}
				value := int(math.Floor(math.Sqrt(c)*255 + 0.5))
				pixels[at] = byte(value)
				at++
				checksum += int64(value)
			}
		}
	}

	file, err := os.Create(os.Args[2])
	if err != nil {
		panic(err)
	}
	writer := bufio.NewWriter(file)
	fmt.Fprintf(writer, "P6\n%d %d\n255\n", width, height)
	writer.Write(pixels)
	writer.Flush()
	file.Close()
	fmt.Printf("Checksum: %d\n", checksum)
}
