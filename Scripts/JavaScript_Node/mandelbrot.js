function mandelbrot(width, height, maxIter) {
    const buffer = new Int32Array(width * height);
    let checksum = 0n;

    const xMin = -2.0;
    const xMax = 1.0;
    const yMin = -1.5;
    const yMax = 1.5;

    const dx = (xMax - xMin) / (width - 1);
    const dy = (yMax - yMin) / (height - 1);

    let index = 0;
    for (let y = 0; y < height; y++) {
        const cy = yMin + y * dy;
        for (let x = 0; x < width; x++) {
            const cx = xMin + x * dx;

            let zx = 0.0;
            let zy = 0.0;
            let iter = 0;

            while (zx * zx + zy * zy <= 4.0 && iter < maxIter) {
                const zx2 = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = zx2;
                iter++;
            }

            buffer[index++] = iter;
            checksum += BigInt(iter);
        }
    }

    return checksum;
}

function main() {
    let width = 2000;
    let height = 2000;
    let maxIter = 1000;

    if (process.argv.length > 2) width = parseInt(process.argv[2], 10);
    if (process.argv.length > 3) height = parseInt(process.argv[3], 10);
    if (process.argv.length > 4) maxIter = parseInt(process.argv[4], 10);

    console.log(mandelbrot(width, height, maxIter).toString());
}

main();