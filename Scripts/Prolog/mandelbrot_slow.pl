:- initialization(main, main).

main(Argv) :-
    parse_args(Argv, Width, Height, MaxIter),
    mandelbrot(Width, Height, MaxIter, _Buffer, Checksum),
    format('~w~n', [Checksum]).

parse_args([], 2000, 2000, 1000).
parse_args([W], Width, 2000, 1000) :-
    atom_number(W, Width).
parse_args([W,H], Width, Height, 1000) :-
    atom_number(W, Width),
    atom_number(H, Height).
parse_args([W,H,M|_], Width, Height, MaxIter) :-
    atom_number(W, Width),
    atom_number(H, Height),
    atom_number(M, MaxIter).

mandelbrot(Width, Height, MaxIter, Buffer, Checksum) :-
    XMin is -2.0,
    XMax is  1.0,
    YMin is -1.5,
    YMax is  1.5,
    DX is (XMax - XMin) / (Width - 1),
    DY is (YMax - YMin) / (Height - 1),
    mandelbrot_rows(0, Height, Width, MaxIter, XMin, YMin, DX, DY, [], Buffer, 0, Checksum).

mandelbrot_rows(Y, Height, _, _, _, _, _, _, Buffer, Buffer, Checksum, Checksum) :-
    Y >= Height, !.
mandelbrot_rows(Y, Height, Width, MaxIter, XMin, YMin, DX, DY, Buffer0, Buffer, Checksum0, Checksum) :-
    CY is YMin + Y * DY,
    mandelbrot_cols(0, Width, MaxIter, XMin, CY, DX, Buffer0, Buffer1, Checksum0, Checksum1),
    Y1 is Y + 1,
    mandelbrot_rows(Y1, Height, Width, MaxIter, XMin, YMin, DX, DY, Buffer1, Buffer, Checksum1, Checksum).

mandelbrot_cols(X, Width, _, _, _, _, Buffer, Buffer, Checksum, Checksum) :-
    X >= Width, !.
mandelbrot_cols(X, Width, MaxIter, XMin, CY, DX, Buffer0, Buffer, Checksum0, Checksum) :-
    CX is XMin + X * DX,
    mandelbrot_iter(CX, CY, MaxIter, 0.0, 0.0, 0, Iter),
    Buffer1 = [Iter | Buffer0],
    Checksum1 is Checksum0 + Iter,
    X1 is X + 1,
    mandelbrot_cols(X1, Width, MaxIter, XMin, CY, DX, Buffer1, Buffer, Checksum1, Checksum).

mandelbrot_iter(_, _, MaxIter, _, _, Iter, Iter) :-
    Iter >= MaxIter, !.
mandelbrot_iter(_, _, _, ZX, ZY, Iter, Iter) :-
    Mag2 is ZX * ZX + ZY * ZY,
    Mag2 > 4.0, !.
mandelbrot_iter(CX, CY, MaxIter, ZX, ZY, Iter0, Iter) :-
    ZX2 is ZX * ZX - ZY * ZY + CX,
    ZY2 is 2.0 * ZX * ZY + CY,
    Iter1 is Iter0 + 1,
    mandelbrot_iter(CX, CY, MaxIter, ZX2, ZY2, Iter1, Iter).