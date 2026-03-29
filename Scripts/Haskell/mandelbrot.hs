import System.Environment (getArgs)
import Data.Array.Unboxed
import Data.Word (Word64)

mandelbrot :: Int -> Int -> Int -> Word64
mandelbrot width height maxIter =
    let xMin = -2.0
        xMax = 1.0
        yMin = -1.5
        yMax = 1.5

        dx = (xMax - xMin) / fromIntegral (width - 1)
        dy = (yMax - yMin) / fromIntegral (height - 1)

        totalSize = width * height

        buffer :: UArray Int Int
        buffer = listArray (0, totalSize - 1)
            [ mandelAt x y | y <- [0..height-1], x <- [0..width-1] ]

        mandelAt x y =
            let cx = xMin + fromIntegral x * dx
                cy = yMin + fromIntegral y * dy
            in iteratePoint cx cy 0.0 0.0 0

        iteratePoint cx cy zx zy iter
            | zx*zx + zy*zy > 4.0 = iter
            | iter >= maxIter     = iter
            | otherwise =
                let zx2 = zx*zx - zy*zy + cx
                    zy2 = 2.0*zx*zy + cy
                in iteratePoint cx cy zx2 zy2 (iter + 1)

        checksum = foldl' (\acc v -> acc + fromIntegral v) 0 buffer

    in checksum

-- strict fold
foldl' :: (a -> b -> a) -> a -> UArray Int b -> a
foldl' f acc arr = go acc (indices arr)
  where
    go !z []     = z
    go !z (i:is) = go (f z (arr ! i)) is

main :: IO ()
main = do
    args <- getArgs

    let width  = if length args > 0 then read (args !! 0) else 2000
        height = if length args > 1 then read (args !! 1) else 2000
        maxIter = if length args > 2 then read (args !! 2) else 1000

    print $ mandelbrot width height maxIter