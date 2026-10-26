# perl mandelbrot.pl [width] [height] [maxIter]
use strict;
use warnings;

sub mandelbrot {
    my ($width, $height, $max_iter) = @_;
    my @buffer = (0) x ($width * $height);
    my $checksum = 0;

    my $x_min = -2.0;
    my $x_max = 1.0;
    my $y_min = -1.5;
    my $y_max = 1.5;

    my $dx = ($x_max - $x_min) / ($width - 1);
    my $dy = ($y_max - $y_min) / ($height - 1);

    my $index = 0;
    for my $y (0 .. $height - 1) {
        my $cy = $y_min + $y * $dy;
        for my $x (0 .. $width - 1) {
            my $cx = $x_min + $x * $dx;

            my $zx = 0.0;
            my $zy = 0.0;
            my $iter = 0;

            while ($zx * $zx + $zy * $zy <= 4.0 && $iter < $max_iter) {
                my $zx2 = $zx * $zx - $zy * $zy + $cx;
                $zy = 2.0 * $zx * $zy + $cy;
                $zx = $zx2;
                $iter++;
            }

            $buffer[$index++] = $iter;
            $checksum += $iter;
        }
    }

    return $checksum;
}

my $width = @ARGV > 0 ? int($ARGV[0]) : 2000;
my $height = @ARGV > 1 ? int($ARGV[1]) : 2000;
my $max_iter = @ARGV > 2 ? int($ARGV[2]) : 1000;

print mandelbrot($width, $height, $max_iter), "\n";
