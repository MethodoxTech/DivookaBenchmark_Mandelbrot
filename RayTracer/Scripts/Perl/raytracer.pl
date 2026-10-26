# Ray tracer benchmark, Perl - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
# perl raytracer.pl <scene.txt> <output.ppm>
# A vector is an array reference [x, y, z].
use strict;
use warnings;
use POSIX qw(floor);

use constant EPSILON => 1e-4;
use constant FAR => 1e30;

sub add { my ($p, $q) = @_; return [$p->[0] + $q->[0], $p->[1] + $q->[1], $p->[2] + $q->[2]]; }
sub vsub { my ($p, $q) = @_; return [$p->[0] - $q->[0], $p->[1] - $q->[1], $p->[2] - $q->[2]]; }
sub scale { my ($p, $s) = @_; return [$p->[0] * $s, $p->[1] * $s, $p->[2] * $s]; }
sub mul { my ($p, $q) = @_; return [$p->[0] * $q->[0], $p->[1] * $q->[1], $p->[2] * $q->[2]]; }
sub vdiv { my ($p, $s) = @_; return [$p->[0] / $s, $p->[1] / $s, $p->[2] / $s]; }
sub dot { my ($p, $q) = @_; return $p->[0] * $q->[0] + $p->[1] * $q->[1] + $p->[2] * $q->[2]; }
sub cross { my ($p, $q) = @_; return [$p->[1] * $q->[2] - $p->[2] * $q->[1], $p->[2] * $q->[0] - $p->[0] * $q->[2], $p->[0] * $q->[1] - $p->[1] * $q->[0]]; }
sub vlength { my ($v) = @_; return sqrt(dot($v, $v)); }
sub normalize { my ($v) = @_; return scale($v, 1.0 / vlength($v)); }

my ($width, $height, $samples, $depth) = (320, 240, 1, 3);
my ($eye, $target, $up, $view) = ([0, 0, 0], [0, 0, 1], [0, 1, 0], 0.5);
my ($background, $ambient) = ([0, 0, 0], [0, 0, 0]);
my (@lights, @shapes, %materials);

# The distance along the ray to the shape, or -1 when the ray misses it.
sub intersect {
    my ($shape, $origin, $direction) = @_;
    if ($shape->{sphere}) {
        my $offset = vsub($origin, $shape->{point});
        my $b = dot($offset, $direction);
        my $c = dot($offset, $offset) - $shape->{radius} * $shape->{radius};
        my $discriminant = $b * $b - $c;
        return -1 if $discriminant < 0;
        my $root = sqrt($discriminant);
        my $t = -$b - $root;
        return $t if $t > EPSILON;
        $t = -$b + $root;
        return $t > EPSILON ? $t : -1;
    }
    my $facing = dot($shape->{normal}, $direction);
    return -1 if abs($facing) < 1e-9;
    my $distance = dot(vsub($shape->{point}, $origin), $shape->{normal}) / $facing;
    return $distance > EPSILON ? $distance : -1;
}

sub shadowed {
    my ($origin, $direction, $distance) = @_;
    for my $shape (@shapes) {
        my $t = intersect($shape, $origin, $direction);
        return 1 if $t > EPSILON && $t < $distance;
    }
    return 0;
}

sub trace {
    my ($origin, $direction, $remaining) = @_;
    my $nearest = FAR;
    my $hit;
    for my $shape (@shapes) {
        my $t = intersect($shape, $origin, $direction);
        if ($t > EPSILON && $t < $nearest) {
            $nearest = $t;
            $hit = $shape;
        }
    }
    return $background unless defined $hit;

    my $point = add($origin, scale($direction, $nearest));
    my $normal = $hit->{sphere} ? vdiv(vsub($point, $hit->{point}), $hit->{radius}) : $hit->{normal};
    $normal = scale($normal, -1) if dot($normal, $direction) > 0;
    my $material = $hit->{material};
    my $colour = $material->{colour};
    if ($material->{scale} > 0) {
        my $k = floor($point->[0] / $material->{scale}) + floor($point->[2] / $material->{scale});
        $colour = $material->{other} if $k - 2 * floor($k / 2) != 0;
    }

    my $result = mul($ambient, $colour);
    my $lifted = add($point, scale($normal, EPSILON));
    for my $light (@lights) {
        my $to_light = vsub($light->[0], $point);
        my $distance = vlength($to_light);
        my $light_direction = normalize($to_light);
        next if shadowed($lifted, $light_direction, $distance);
        my $diffuse = dot($normal, $light_direction);
        if ($diffuse > 0) {
            $result = add($result, scale(mul($colour, $light->[1]), $material->{diffuse} * $diffuse));
            my $reflected = vsub(scale($normal, 2 * $diffuse), $light_direction);
            my $specular = -dot($reflected, $direction);
            if ($specular > 0) {
                my $power = 1;
                $power = $power * $specular for 1 .. $material->{shininess};
                $result = add($result, scale($light->[1], $material->{specular} * $power));
            }
        }
    }

    if ($remaining > 0 && $material->{reflect} > 0) {
        my $bounced = vsub($direction, scale($normal, 2 * dot($direction, $normal)));
        my $mirrored = trace($lifted, $bounced, $remaining - 1);
        $result = add(scale($result, 1 - $material->{reflect}), scale($mirrored, $material->{reflect}));
    }
    return $result;
}

sub load {
    my ($path) = @_;
    open(my $file, '<', $path) or die "Cannot open $path: $!";
    while (my $raw = <$file>) {
        $raw =~ s/#.*//s;
        my @w = split ' ', $raw;
        next unless @w;
        my $n = sub { return 0 + $w[$_[0]]; };
        my $v = sub { my $i = $_[0]; return [$n->($i), $n->($i + 1), $n->($i + 2)]; };
        my $d = $w[0];
        if ($d eq 'size') { ($width, $height) = (int($w[1]), int($w[2])); }
        elsif ($d eq 'samples') { $samples = int($w[1]); }
        elsif ($d eq 'depth') { $depth = int($w[1]); }
        elsif ($d eq 'camera') { ($eye, $target, $up, $view) = ($v->(1), $v->(4), $v->(7), $n->(10)); }
        elsif ($d eq 'background') { $background = $v->(1); }
        elsif ($d eq 'ambient') { $ambient = $v->(1); }
        elsif ($d eq 'light') { push @lights, [$v->(1), $v->(4)]; }
        elsif ($d eq 'material') {
            $materials{$w[1]} = { colour => $v->(2), other => $v->(2), scale => 0, diffuse => $n->(5), specular => $n->(6), shininess => int($w[7]), reflect => $n->(8) };
        }
        elsif ($d eq 'checker') {
            $materials{$w[1]} = { colour => $v->(2), other => $v->(5), scale => $n->(8), diffuse => $n->(9), specular => $n->(10), shininess => int($w[11]), reflect => $n->(12) };
        }
        elsif ($d eq 'sphere') { push @shapes, { sphere => 1, point => $v->(1), radius => $n->(4), material => $materials{$w[5]} }; }
        elsif ($d eq 'plane') { push @shapes, { sphere => 0, point => $v->(1), normal => normalize($v->(4)), material => $materials{$w[7]} }; }
        else { die "Unknown directive '$d'.\n"; }
    }
    close($file);
}

die "Usage: raytracer <scene.txt> <output.ppm>\n" if @ARGV < 2;
load($ARGV[0]);

my $forward = normalize(vsub($target, $eye));
my $right = normalize(cross($up, $forward));
my $upward = cross($forward, $right);
my $aspect = $width / $height;

my @pixels;
my $checksum = 0;
for my $py (0 .. $height - 1) {
    for my $px (0 .. $width - 1) {
        my $colour = [0, 0, 0];
        for my $sy (0 .. $samples - 1) {
            for my $sx (0 .. $samples - 1) {
                my $u = ($px + ($sx + 0.5) / $samples) / $width * 2 - 1;
                my $v = 1 - ($py + ($sy + 0.5) / $samples) / $height * 2;
                my $direction = normalize(add(add($forward, scale($right, $u * $aspect * $view)), scale($upward, $v * $view)));
                $colour = add($colour, trace($eye, $direction, $depth));
            }
        }
        $colour = vdiv($colour, $samples * $samples);
        for my $channel (@$colour) {
            my $c = $channel < 0 ? 0 : $channel > 1 ? 1 : $channel;
            my $value = floor(sqrt($c) * 255 + 0.5);
            push @pixels, $value;
            $checksum += $value;
        }
    }
}

open(my $out, '>:raw', $ARGV[1]) or die "Cannot write $ARGV[1]: $!";
print $out "P6\n$width $height\n255\n";
print $out pack('C*', @pixels);
close($out);
print "Checksum: $checksum\n";
