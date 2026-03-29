package main

import (
	"fmt"
	"os"
	"strconv"
)

func mandelbrot(width, height, maxIter int) uint64 {
	buffer := make([]int, width*height)
	var checksum uint64

	xMin := -2.0
	xMax := 1.0
	yMin := -1.5
	yMax := 1.5

	dx := (xMax - xMin) / float64(width-1)
	dy := (yMax - yMin) / float64(height-1)

	index := 0
	for y := 0; y < height; y++ {
		cy := yMin + float64(y)*dy
		for x := 0; x < width; x++ {
			cx := xMin + float64(x)*dx

			zx := 0.0
			zy := 0.0
			iter := 0

			for zx*zx+zy*zy <= 4.0 && iter < maxIter {
				zx2 := zx*zx - zy*zy + cx
				zy = 2.0*zx*zy + cy
				zx = zx2
				iter++
			}

			buffer[index] = iter
			checksum += uint64(iter)
			index++
		}
	}

	return checksum
}

func main() {
	width := 2000
	height := 2000
	maxIter := 1000

	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			width = v
		}
	}
	if len(os.Args) > 2 {
		if v, err := strconv.Atoi(os.Args[2]); err == nil {
			height = v
		}
	}
	if len(os.Args) > 3 {
		if v, err := strconv.Atoi(os.Args[3]); err == nil {
			maxIter = v
		}
	}

	fmt.Println(mandelbrot(width, height, maxIter))
}