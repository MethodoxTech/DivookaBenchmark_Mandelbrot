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

    Width1 is Width - 1,
    Height1 is Height - 1,

    findall(
        Iter,
        (
            between(0, Height1, Y),
            CY is YMin + Y * DY,
            between(0, Width1, X),
            CX is XMin + X * DX,
            mandelbrot_iter(CX, CY, MaxIter, 0.0, 0.0, 0, Iter)
        ),
        Buffer
    ),

    sum_list(Buffer, Checksum).

mandelbrot_iter(_, _, MaxIter, _, _, Iter, Iter) :-
    Iter >= MaxIter,
    !.
mandelbrot_iter(_, _, _, ZX, ZY, Iter, Iter) :-
    ZX * ZX + ZY * ZY > 4.0,
    !.
mandelbrot_iter(CX, CY, MaxIter, ZX, ZY, Iter0, Iter) :-
    ZX2 is ZX * ZX - ZY * ZY + CX,
    ZY2 is 2.0 * ZX * ZY + CY,
    Iter1 is Iter0 + 1,
    mandelbrot_iter(CX, CY, MaxIter, ZX2, ZY2, Iter1, Iter).