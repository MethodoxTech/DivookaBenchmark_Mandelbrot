{-# LANGUAGE BangPatterns #-}
-- Ray tracer benchmark, Haskell - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
-- ghc -O2 raytracer.hs -o raytracer
-- raytracer <scene.txt> <output.ppm>
-- GHC does not fuse a multiply and an add on its own, so every operation is rounded as the reference rounds it.
module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import qualified Data.Map.Strict as Map
import Data.List (foldl')
import Data.Word (Word8)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

data Vec = Vec {-# UNPACK #-} !Double {-# UNPACK #-} !Double {-# UNPACK #-} !Double

add, sub, mul :: Vec -> Vec -> Vec
add (Vec a b c) (Vec x y z) = Vec (a + x) (b + y) (c + z)
sub (Vec a b c) (Vec x y z) = Vec (a - x) (b - y) (c - z)
mul (Vec a b c) (Vec x y z) = Vec (a * x) (b * y) (c * z)

scale, divide :: Vec -> Double -> Vec
scale (Vec a b c) s = Vec (a * s) (b * s) (c * s)
divide (Vec a b c) s = Vec (a / s) (b / s) (c / s)

dot :: Vec -> Vec -> Double
dot (Vec a b c) (Vec x y z) = a * x + b * y + c * z

cross :: Vec -> Vec -> Vec
cross (Vec ax ay az) (Vec bx by bz) = Vec (ay * bz - az * by) (az * bx - ax * bz) (ax * by - ay * bx)

vlength :: Vec -> Double
vlength v = sqrt (dot v v)

normalize :: Vec -> Vec
normalize v = scale v (1.0 / vlength v)

data Material = Material
  { colour :: !Vec, other :: !Vec, checker :: !Double
  , diffuse :: !Double, specular :: !Double, shininess :: !Int, reflectivity :: !Double }

data Shape = Sphere !Vec !Double !Material | Plane !Vec !Vec !Material

data Scene = Scene
  { width :: !Int, height :: !Int, samples :: !Int, depth :: !Int
  , eye :: !Vec, target :: !Vec, up :: !Vec, view :: !Double
  , background :: !Vec, ambient :: !Vec
  , lights :: [(Vec, Vec)], shapes :: [Shape], materials :: Map.Map String Material }

epsilon, far :: Double
epsilon = 1e-4
far = 1e30

-- The distance along the ray to the shape, or -1 when the ray misses it.
intersect :: Shape -> Vec -> Vec -> Double
intersect (Sphere centre radius _) origin direction =
  let offset = sub origin centre
      b = dot offset direction
      c = dot offset offset - radius * radius
      discriminant = b * b - c
  in if discriminant < 0 then -1
     else let root = sqrt discriminant
              t1 = negate b - root
              t2 = negate b + root
          in if t1 > epsilon then t1 else if t2 > epsilon then t2 else -1
intersect (Plane point normal _) origin direction =
  let facing = dot normal direction
  in if abs facing < 1e-9 then -1
     else let distance = dot (sub point origin) normal / facing
          in if distance > epsilon then distance else -1

shadowed :: Scene -> Vec -> Vec -> Double -> Bool
shadowed scene origin direction distance = any blocks (shapes scene)
  where blocks shape = let t = intersect shape origin direction in t > epsilon && t < distance

nearestHit :: Scene -> Vec -> Vec -> (Double, Maybe Shape)
nearestHit scene origin direction = foldl' step (far, Nothing) (shapes scene)
  where step (!nearest, hit) shape =
          let t = intersect shape origin direction
          in if t > epsilon && t < nearest then (t, Just shape) else (nearest, hit)

power :: Double -> Int -> Double
power x n = go 1 n
  where go !acc 0 = acc
        go !acc k = go (acc * x) (k - 1)

trace :: Scene -> Vec -> Vec -> Int -> Vec
trace scene origin direction remaining =
  case nearestHit scene origin direction of
    (_, Nothing) -> background scene
    (nearest, Just hit) ->
      let point = add origin (scale direction nearest)
          (normal0, material) = case hit of
            Sphere centre radius m -> (divide (sub point centre) radius, m)
            Plane _ normal m -> (normal, m)
          normal = if dot normal0 direction > 0 then scale normal0 (-1) else normal0
          Vec px _ pz = point
          base = if checker material > 0
                   then let k = fromIntegral (floor (px / checker material) :: Integer) + fromIntegral (floor (pz / checker material) :: Integer) :: Double
                        in if k - 2 * fromIntegral (floor (k / 2) :: Integer) /= 0 then other material else colour material
                   else colour material
          lifted = add point (scale normal epsilon)
          shade result (position, lightColour) =
            let toLight = sub position point
                distance = vlength toLight
                lightDirection = normalize toLight
            in if shadowed scene lifted lightDirection distance then result
               else let d = dot normal lightDirection
                    in if d > 0
                         then let lit = add result (scale (mul base lightColour) (diffuse material * d))
                                  reflected = sub (scale normal (2 * d)) lightDirection
                                  s = negate (dot reflected direction)
                              in if s > 0 then add lit (scale lightColour (specular material * power s (shininess material))) else lit
                         else result
          shaded = foldl' shade (mul (ambient scene) base) (lights scene)
      in if remaining > 0 && reflectivity material > 0
           then let bounced = sub direction (scale normal (2 * dot direction normal))
                    mirrored = trace scene lifted bounced (remaining - 1)
                in add (scale shaded (1 - reflectivity material)) (scale mirrored (reflectivity material))
           else shaded

load :: String -> Scene
load text = foldl' directive initial (lines text)
  where
    initial = Scene 320 240 1 3 (Vec 0 0 0) (Vec 0 0 1) (Vec 0 1 0) 0.5 (Vec 0 0 0) (Vec 0 0 0) [] [] Map.empty
    directive scene raw =
      case words (takeWhile (/= '#') raw) of
        [] -> scene
        w@(d : _) ->
          let n i = read (w !! i) :: Double
              v i = Vec (n i) (n (i + 1)) (n (i + 2))
              int i = read (w !! i) :: Int
          in case d of
               "size" -> scene { width = int 1, height = int 2 }
               "samples" -> scene { samples = int 1 }
               "depth" -> scene { depth = int 1 }
               "camera" -> scene { eye = v 1, target = v 4, up = v 7, view = n 10 }
               "background" -> scene { background = v 1 }
               "ambient" -> scene { ambient = v 1 }
               "light" -> scene { lights = lights scene ++ [(v 1, v 4)] }
               "material" -> scene { materials = Map.insert (w !! 1) (Material (v 2) (v 2) 0 (n 5) (n 6) (int 7) (n 8)) (materials scene) }
               "checker" -> scene { materials = Map.insert (w !! 1) (Material (v 2) (v 5) (n 8) (n 9) (n 10) (int 11) (n 12)) (materials scene) }
               "sphere" -> scene { shapes = shapes scene ++ [Sphere (v 1) (n 4) (materials scene Map.! (w !! 5))] }
               "plane" -> scene { shapes = shapes scene ++ [Plane (v 1) (normalize (v 4)) (materials scene Map.! (w !! 7))] }
               _ -> error ("Unknown directive '" ++ d ++ "'.")

render :: Scene -> [Int]
render scene =
  [ value
  | py <- [0 .. h - 1], px <- [0 .. w - 1]
  , let Vec r g b = divide (pixel px py) (fromIntegral (s * s))
  , channel <- [r, g, b]
  , let c = if channel < 0 then 0 else if channel > 1 then 1 else channel
  , let value = floor (sqrt c * 255 + 0.5) ]
  where
    w = width scene
    h = height scene
    s = samples scene
    forward = normalize (sub (target scene) (eye scene))
    right = normalize (cross (up scene) forward)
    upward = cross forward right
    aspect = fromIntegral w / fromIntegral h :: Double
    pixel px py = foldl' add (Vec 0 0 0)
      [ trace scene (eye scene) direction (depth scene)
      | sy <- [0 .. s - 1], sx <- [0 .. s - 1]
      , let u = (fromIntegral px + (fromIntegral sx + 0.5) / fromIntegral s) / fromIntegral w * 2 - 1
      , let v = 1 - (fromIntegral py + (fromIntegral sy + 0.5) / fromIntegral s) / fromIntegral h * 2
      , let direction = normalize (add (add forward (scale right (u * aspect * view scene))) (scale upward (v * view scene))) ]

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    (scenePath : outputPath : _) -> do
      scene <- load <$> readFile scenePath
      let values = render scene
          header = BC.pack ("P6\n" ++ show (width scene) ++ " " ++ show (height scene) ++ "\n255\n")
          pixels = BS.pack (map fromIntegral values :: [Word8])
      BS.writeFile outputPath (BS.append header pixels)
      putStrLn ("Checksum: " ++ show (sum values))
    _ -> hPutStrLn stderr "Usage: raytracer <scene.txt> <output.ppm>" >> exitFailure
