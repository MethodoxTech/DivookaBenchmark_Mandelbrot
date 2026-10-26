% Ray tracer benchmark, SWI-Prolog - follows the C# reference (RayTracer/Scripts/C#) operation for operation.
% swipl raytracer.pl <scene.txt> <output.ppm>
% A vector is v(X, Y, Z). Every number read from the scene is made a float, so all arithmetic is in IEEE doubles.
:- initialization(main, main).

epsilon(1.0e-4).
far(1.0e30).

add(v(A, B, C), v(X, Y, Z), v(P, Q, R)) :- P is A + X, Q is B + Y, R is C + Z.
sub(v(A, B, C), v(X, Y, Z), v(P, Q, R)) :- P is A - X, Q is B - Y, R is C - Z.
scale(v(A, B, C), S, v(P, Q, R)) :- P is A * S, Q is B * S, R is C * S.
mul(v(A, B, C), v(X, Y, Z), v(P, Q, R)) :- P is A * X, Q is B * Y, R is C * Z.
divide(v(A, B, C), S, v(P, Q, R)) :- P is A / S, Q is B / S, R is C / S.
dot(v(A, B, C), v(X, Y, Z), D) :- D is A * X + B * Y + C * Z.
cross(v(AX, AY, AZ), v(BX, BY, BZ), v(P, Q, R)) :-
    P is AY * BZ - AZ * BY, Q is AZ * BX - AX * BZ, R is AX * BY - AY * BX.
vlength(V, L) :- dot(V, V, D), L is sqrt(D).
normalize(V, N) :- vlength(V, L), S is 1.0 / L, scale(V, S, N).

% The distance along the ray to the shape, or -1 when the ray misses it.
intersect(sphere(Centre, Radius, _), Origin, Direction, T) :-
    epsilon(E),
    sub(Origin, Centre, Offset),
    dot(Offset, Direction, B),
    dot(Offset, Offset, OO),
    C is OO - Radius * Radius,
    Discriminant is B * B - C,
    (   Discriminant < 0 -> T = -1.0
    ;   Root is sqrt(Discriminant),
        T1 is -B - Root,
        (   T1 > E -> T = T1
        ;   T2 is -B + Root,
            ( T2 > E -> T = T2 ; T = -1.0 )
        )
    ).
intersect(plane(Point, Normal, _), Origin, Direction, T) :-
    epsilon(E),
    dot(Normal, Direction, Facing),
    (   abs(Facing) < 1.0e-9 -> T = -1.0
    ;   sub(Point, Origin, Offset),
        dot(Offset, Normal, Along),
        Distance is Along / Facing,
        ( Distance > E -> T = Distance ; T = -1.0 )
    ).

shadowed([Shape | Shapes], Origin, Direction, Distance) :-
    intersect(Shape, Origin, Direction, T),
    epsilon(E),
    (   T > E, T < Distance -> true
    ;   shadowed(Shapes, Origin, Direction, Distance)
    ).

nearest([], _, _, Nearest, Hit, Nearest, Hit).
nearest([Shape | Shapes], Origin, Direction, Nearest0, Hit0, Nearest, Hit) :-
    intersect(Shape, Origin, Direction, T),
    epsilon(E),
    (   T > E, T < Nearest0
    ->  nearest(Shapes, Origin, Direction, T, Shape, Nearest, Hit)
    ;   nearest(Shapes, Origin, Direction, Nearest0, Hit0, Nearest, Hit)
    ).

power(_, 0, Acc, Acc) :- !.
power(X, N, Acc0, Acc) :- Acc1 is Acc0 * X, N1 is N - 1, power(X, N1, Acc1, Acc).

trace(Scene, Origin, Direction, Remaining, Colour) :-
    Scene = scene(_, _, _, _, _, _, _, _, Background, Ambient, Lights, Shapes),
    far(Far),
    nearest(Shapes, Origin, Direction, Far, none, Nearest, Hit),
    (   Hit == none -> Colour = Background
    ;   scale(Direction, Nearest, Step),
        add(Origin, Step, Point),
        (   Hit = sphere(Centre, Radius, Material)
        ->  sub(Point, Centre, Out), divide(Out, Radius, Normal0)
        ;   Hit = plane(_, Normal0, Material)
        ),
        dot(Normal0, Direction, Facing),
        ( Facing > 0 -> scale(Normal0, -1.0, Normal) ; Normal = Normal0 ),
        Material = material(Plain, Other, Check, Diffuse, Specular, Shininess, Reflect),
        Point = v(PX, _, PZ),
        (   Check > 0
        ->  K is float(floor(PX / Check)) + float(floor(PZ / Check)),
            ( K - 2 * float(floor(K / 2)) =\= 0 -> Base = Other ; Base = Plain )
        ;   Base = Plain
        ),
        epsilon(E),
        scale(Normal, E, Lift),
        add(Point, Lift, Lifted),
        mul(Ambient, Base, Start),
        foldl(shade(Shapes, Point, Normal, Lifted, Direction, Base, Diffuse, Specular, Shininess), Lights, Start, Shaded),
        (   Remaining > 0, Reflect > 0
        ->  dot(Direction, Normal, DN),
            Twice is 2 * DN,
            scale(Normal, Twice, Away),
            sub(Direction, Away, Bounced),
            Next is Remaining - 1,
            trace(Scene, Lifted, Bounced, Next, Mirrored),
            Keep is 1 - Reflect,
            scale(Shaded, Keep, Kept),
            scale(Mirrored, Reflect, Taken),
            add(Kept, Taken, Colour)
        ;   Colour = Shaded
        )
    ).

shade(Shapes, Point, Normal, Lifted, Direction, Base, Diffuse, Specular, Shininess, light(Position, LightColour), Result0, Result) :-
    sub(Position, Point, ToLight),
    vlength(ToLight, Distance),
    normalize(ToLight, LightDirection),
    (   shadowed(Shapes, Lifted, LightDirection, Distance) -> Result = Result0
    ;   dot(Normal, LightDirection, D),
        (   D > 0
        ->  mul(Base, LightColour, Tint),
            Amount is Diffuse * D,
            scale(Tint, Amount, Lit),
            add(Result0, Lit, Result1),
            Twice is 2 * D,
            scale(Normal, Twice, Doubled),
            sub(Doubled, LightDirection, Reflected),
            dot(Reflected, Direction, RD),
            S is -RD,
            (   S > 0
            ->  power(S, Shininess, 1.0, P),
                Strength is Specular * P,
                scale(LightColour, Strength, Highlight),
                add(Result1, Highlight, Result)
            ;   Result = Result1
            )
        ;   Result = Result0
        )
    ).

% The scene: scene(Width, Height, Samples, Depth, Eye, Target, Up, View, Background, Ambient, Lights, Shapes).
load(Path, Scene) :-
    read_file_to_string(Path, Text, []),
    split_string(Text, "\n", "\r", Lines),
    foldl(directive, Lines, state(320, 240, 1, 3, v(0.0, 0.0, 0.0), v(0.0, 0.0, 1.0), v(0.0, 1.0, 0.0), 0.5, v(0.0, 0.0, 0.0), v(0.0, 0.0, 0.0), [], [], []), State),
    State = state(W, H, S, D, Eye, Target, Up, View, Background, Ambient, Lights, Shapes, _),
    reverse(Lights, LightsInOrder),
    reverse(Shapes, ShapesInOrder),
    Scene = scene(W, H, S, D, Eye, Target, Up, View, Background, Ambient, LightsInOrder, ShapesInOrder).

directive(Raw, State0, State) :-
    split_string(Raw, "#", "", [Line | _]),
    split_string(Line, " \t", " \t", Parts),
    exclude(==(""), Parts, Words),
    (   Words == [] -> State = State0
    ;   Words = [Directive | Args],
        apply_directive(Directive, Args, State0, State)
    ).

to_float(Text, Value) :- number_string(N, Text), Value is float(N).
to_int(Text, Value) :- number_string(Value, Text).
floats(Texts, Values) :- maplist(to_float, Texts, Values).

apply_directive("size", [W, H], state(_, _, S, D, E, T, U, V, B, A, L, Sh, M), state(Wi, Hi, S, D, E, T, U, V, B, A, L, Sh, M)) :-
    to_int(W, Wi), to_int(H, Hi).
apply_directive("samples", [S], state(W, H, _, D, E, T, U, V, B, A, L, Sh, M), state(W, H, Si, D, E, T, U, V, B, A, L, Sh, M)) :-
    to_int(S, Si).
apply_directive("depth", [D], state(W, H, S, _, E, T, U, V, B, A, L, Sh, M), state(W, H, S, Di, E, T, U, V, B, A, L, Sh, M)) :-
    to_int(D, Di).
apply_directive("camera", Args, state(W, H, S, D, _, _, _, _, B, A, L, Sh, M), state(W, H, S, D, v(EX, EY, EZ), v(TX, TY, TZ), v(UX, UY, UZ), View, B, A, L, Sh, M)) :-
    floats(Args, [EX, EY, EZ, TX, TY, TZ, UX, UY, UZ, View]).
apply_directive("background", Args, state(W, H, S, D, E, T, U, V, _, A, L, Sh, M), state(W, H, S, D, E, T, U, V, v(R, G, Bl), A, L, Sh, M)) :-
    floats(Args, [R, G, Bl]).
apply_directive("ambient", Args, state(W, H, S, D, E, T, U, V, B, _, L, Sh, M), state(W, H, S, D, E, T, U, V, B, v(R, G, Bl), L, Sh, M)) :-
    floats(Args, [R, G, Bl]).
apply_directive("light", Args, state(W, H, S, D, E, T, U, V, B, A, L, Sh, M), state(W, H, S, D, E, T, U, V, B, A, [light(v(PX, PY, PZ), v(R, G, Bl)) | L], Sh, M)) :-
    floats(Args, [PX, PY, PZ, R, G, Bl]).
apply_directive("material", [Name, R, G, Bl, Di, Sp, Sh0, Re], state(W, H, S, D, E, T, U, V, B, A, L, Sh, M), state(W, H, S, D, E, T, U, V, B, A, L, Sh, [Name-material(v(Rf, Gf, Bf), v(Rf, Gf, Bf), 0.0, Dif, Spf, Shi, Ref) | M])) :-
    floats([R, G, Bl, Di, Sp, Re], [Rf, Gf, Bf, Dif, Spf, Ref]),
    to_int(Sh0, Shi).
apply_directive("checker", [Name, R1, G1, B1, R2, G2, B2, Sc, Di, Sp, Sh0, Re], state(W, H, S, D, E, T, U, V, B, A, L, Sh, M), state(W, H, S, D, E, T, U, V, B, A, L, Sh, [Name-material(v(R1f, G1f, B1f), v(R2f, G2f, B2f), Scf, Dif, Spf, Shi, Ref) | M])) :-
    floats([R1, G1, B1, R2, G2, B2, Sc, Di, Sp, Re], [R1f, G1f, B1f, R2f, G2f, B2f, Scf, Dif, Spf, Ref]),
    to_int(Sh0, Shi).
apply_directive("sphere", [X, Y, Z, Rad, Name], state(W, H, S, D, E, T, U, V, B, A, L, Sh, M), state(W, H, S, D, E, T, U, V, B, A, L, [sphere(v(Xf, Yf, Zf), Radf, Material) | Sh], M)) :-
    floats([X, Y, Z, Rad], [Xf, Yf, Zf, Radf]),
    memberchk(Name-Material, M).
apply_directive("plane", [X, Y, Z, NX, NY, NZ, Name], state(W, H, S, D, E, T, U, V, B, A, L, Sh, M), state(W, H, S, D, E, T, U, V, B, A, L, [plane(v(Xf, Yf, Zf), Normal, Material) | Sh], M)) :-
    floats([X, Y, Z, NX, NY, NZ], [Xf, Yf, Zf, NXf, NYf, NZf]),
    normalize(v(NXf, NYf, NZf), Normal),
    memberchk(Name-Material, M).

channel_value(Channel, Value) :-
    ( Channel < 0 -> C = 0.0 ; Channel > 1 -> C = 1.0 ; C = Channel ),
    Value is floor(sqrt(C) * 255 + 0.5).

% The pixel's samples summed, row by row of the sample grid and across each row, as the reference adds them.
samples_sum(Scene, Basis, PX, PY, Colour) :-
    Scene = scene(_, _, S, _, _, _, _, _, _, _, _, _),
    sample_rows(Scene, Basis, PX, PY, 0, S, v(0.0, 0.0, 0.0), Colour).

sample_rows(Scene, Basis, PX, PY, SY, S, Acc0, Acc) :-
    (   SY >= S -> Acc = Acc0
    ;   sample_columns(Scene, Basis, PX, PY, SY, 0, S, Acc0, Acc1),
        SY1 is SY + 1,
        sample_rows(Scene, Basis, PX, PY, SY1, S, Acc1, Acc)
    ).

sample_columns(Scene, Basis, PX, PY, SY, SX, S, Acc0, Acc) :-
    (   SX >= S -> Acc = Acc0
    ;   Scene = scene(W, H, _, D, Eye, _, _, View, _, _, _, _),
        Basis = basis(Forward, Right, Upward, Aspect),
        U is (PX + (SX + 0.5) / S) / W * 2 - 1,
        V is 1 - (PY + (SY + 0.5) / S) / H * 2,
        UA is U * Aspect * View,
        VV is V * View,
        scale(Right, UA, Across),
        scale(Upward, VV, Upwards),
        add(Forward, Across, Aim0),
        add(Aim0, Upwards, Aim),
        normalize(Aim, Direction),
        trace(Scene, Eye, Direction, D, Sample),
        add(Acc0, Sample, Acc1),
        SX1 is SX + 1,
        sample_columns(Scene, Basis, PX, PY, SY, SX1, S, Acc1, Acc)
    ).

render_rows(Scene, Basis, Stream, PY, Checksum0, Checksum) :-
    Scene = scene(W, H, _, _, _, _, _, _, _, _, _, _),
    (   PY >= H -> Checksum = Checksum0
    ;   render_columns(Scene, Basis, Stream, PY, 0, W, Checksum0, Checksum1),
        PY1 is PY + 1,
        render_rows(Scene, Basis, Stream, PY1, Checksum1, Checksum)
    ).

render_columns(Scene, Basis, Stream, PY, PX, W, Checksum0, Checksum) :-
    (   PX >= W -> Checksum = Checksum0
    ;   samples_sum(Scene, Basis, PX, PY, Sum),
        Scene = scene(_, _, S, _, _, _, _, _, _, _, _, _),
        Count is float(S * S),
        divide(Sum, Count, v(R, G, B)),
        channel_value(R, RV), channel_value(G, GV), channel_value(B, BV),
        put_byte(Stream, RV), put_byte(Stream, GV), put_byte(Stream, BV),
        Checksum1 is Checksum0 + RV + GV + BV,
        PX1 is PX + 1,
        render_columns(Scene, Basis, Stream, PY, PX1, W, Checksum1, Checksum)
    ).

main(Argv) :-
    (   Argv = [ScenePath, OutputPath | _]
    ->  load(ScenePath, Scene),
        Scene = scene(W, H, _, _, Eye, Target, Up, _, _, _, _, _),
        sub(Target, Eye, Ahead), normalize(Ahead, Forward),
        cross(Up, Forward, Side), normalize(Side, Right),
        cross(Forward, Right, Upward),
        Aspect is W / H,
        format(atom(Header), "P6~n~w ~w~n255~n", [W, H]),
        open(OutputPath, write, Stream, [type(binary)]),
        atom_codes(Header, Codes),
        forall(member(Code, Codes), put_byte(Stream, Code)),
        render_rows(Scene, basis(Forward, Right, Upward, Aspect), Stream, 0, 0, Checksum),
        close(Stream),
        format("Checksum: ~w~n", [Checksum])
    ;   format(user_error, "Usage: raytracer <scene.txt> <output.ppm>~n", []),
        halt(1)
    ).
