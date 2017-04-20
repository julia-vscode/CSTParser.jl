using Base.Test

randop() = rand(["-->", "→",
                 "||", 
                 "&&",
                 "<", "==", "<:", ">:",
                 "<|", "|>", 
                 ":",
                 "+", "-", 
                 ">>", "<<", 
                 "*", "/", 
                 "//",
                 "^", "↑",
                 "::",
                 "."])


function test_expr(str)
    x, ps = Parser.parse(Parser.ParseState(str))
    x0 = Expr(x)
    x1 = remlineinfo!(Base.parse(str))
    !ps.errored && x0 == x1 && isempty(Parser.span(x))
end

@testset "Operators" begin
    @testset "Binary Operators" begin
        for iter = 1:250
            str = join([["x$(randop())" for i = 1:19];"x"])
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
    @testset "Conditional Operator" begin
        strs = ["a ? b : c"
                "a ? b:c : d"
                "a ? b:c : d:e"]
        for str in strs
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    
    @testset "Dot Operator" begin
        @test "a.b"  |> test_expr
        @test "a.b.c"  |> test_expr
        @test "(a(b)).c"  |> test_expr
        @test "(a).(b).(c)"  |> test_expr
        @test "(a).b.(c)"  |> test_expr
        @test "(a).b.(c+d)"  |> test_expr
    end

    @testset "Unary Operator" begin
        @test "+" |> test_expr
        @test "-" |> test_expr
        @test "!" |> test_expr
        @test "~" |> test_expr
        @test "&" |> test_expr
        @test "::" |> test_expr
        @test "<:" |> test_expr
        @test ">:" |> test_expr
        @test "¬" |> test_expr
        @test "√" |> test_expr
        @test "∛" |> test_expr
        @test "∜" |> test_expr
    end

    @testset "unary op calls" begin
        @test "+(a,b)" |> test_expr
        @test "-(a,b)" |> test_expr
        @test "!(a,b)" |> test_expr
        @test "¬(a,b)" |> test_expr
        @test "~(a,b)" |> test_expr
        @test "<:(a,b)" |> test_expr
        @test "√(a,b)" |> test_expr
        @test "\$(a,b)" |> test_expr
        @test ":(a,b)" |> test_expr
        @test "&a" |> test_expr
        @test "&(a,b)" |> test_expr
        @test "::a" |> test_expr
        @test "::(a,b)" |> test_expr
    end
end


@testset "Type Annotations" begin
    @testset "Curly" begin
        @test "x{T}" |> test_expr
        @test "x{T,S}" |> test_expr
        @test "a.b{T}" |> test_expr
        @test "a(b){T}" |> test_expr
        @test "(a(b)){T}" |> test_expr
        @test "a{b}{T}" |> test_expr
        @test "a{b}(c){T}" |> test_expr
        @test "a{b}.c{T}" |> test_expr
        @test """x{T, 
        S}""" |> test_expr
    end
end

@testset "Tuples" begin
    @test "1," |> test_expr
    @test "1,2" |> test_expr
    @test "1,2,3" |> test_expr
    @test "()" |> test_expr
    @test "(==)" |> test_expr
    @test "(1)" |> test_expr
    @test "(1,)" |> test_expr
    @test "(1,2)" |> test_expr
    @test "(a,b,c)" |> test_expr
    @test "(a...)" |> test_expr
    @test "((a,b)...)" |> test_expr
    @test "a,b = c,d" |> test_expr
    @test "(a,b) = (c,d)" |> test_expr
end

@testset "Function Calls" begin
    @testset "Simple Calls" begin
        @test "f(x)" |> test_expr
        @test "f(x,y)" |> test_expr
        @test "f(g(x))" |> test_expr
        @test "f((x,y))" |> test_expr
        @test "f((x,y), z)" |> test_expr
        @test "f(z, (x,y), z)" |> test_expr
        @test "f{a}(x)" |> test_expr
        @test "f{a<:T}(x::T)" |> test_expr
    end

    @testset "Keyword Arguments" begin
        @test "f(x=1)" |> test_expr
        @test "f(x=1,y::Int = 1)" |> test_expr
    end

    @testset "Compact Declaration" begin
        @test "f(x) = x" |> test_expr
        @test "f(x) = g(x)" |> test_expr
        @test "f(x) = (x)" |> test_expr
        @test "f(x) = (x;y)" |> test_expr
        @test "f(g(x)) = x" |> test_expr
        @test "f(g(x)) = h(x)" |> test_expr
    end

    @testset "Standard Declaration" begin
        @test "function f end" |> test_expr
        @test "function f(x) x end" |> test_expr
        @test "function f(x); x; end" |> test_expr
        @test "function f(x) x; end" |> test_expr
        @test "function f(x); x end" |> test_expr
        @test "function f(x) x;y end" |> test_expr
        @test """function f(x) 
            x
        end""" |> test_expr
        @test """function f(x,y =1)
            x
        end""" |> test_expr
        @test """function f(x,y =1;z =2)
            x
        end""" |> test_expr
    end
    @testset "Anonymous" begin
        @test "x->y" |> test_expr
        @test "(x,y)->x*y" |> test_expr
        @test """function ()
            return 
        end""" |> test_expr
    end
end





@testset "Types" begin
    @testset "Abstract" begin
        @test "abstract t" |> test_expr
        @test "abstract t{T}" |> test_expr
        @test "abstract t <: S" |> test_expr
        @test "abstract t{T} <: S" |> test_expr
    end

    @testset "Bitstype" begin
        @test "bitstype 64 Int" |> test_expr
        @test "bitstype 4*16 Int" |> test_expr
    end

    @testset "Typealias" begin
        @test "typealias name fsd" |> test_expr
    end

    @testset "Structs" begin
        @test "type a end" |> test_expr
        @test "type a; end" |> test_expr
        @test "type a; b;end" |> test_expr
        @test """type a
            arg1
        end""" |> test_expr
        @test """type a <: T
            arg1::Int
            arg2::Int
        end""" |> test_expr
        @test """type a
            arg1::T
        end""" |> test_expr
        @test """type a{T}
            arg1::T
            a(args) = new(args)
        end""" |> test_expr
        @test """type a <: Int
            arg1::Vector{Int}
        end""" |> test_expr
        @test """immutable a <: Int
            arg1::Vector{Int}
        end""" |> test_expr
    end
end


@testset "Modules" begin
    @testset "Import/using " begin
        @test "import ModA" |> test_expr
        @test "import .ModA" |> test_expr
        @test "import ..ModA.a" |> test_expr
        @test "import ModA.subModA" |> test_expr
        @test "import ModA.subModA: a" |> test_expr
        @test "import ModA.subModA: a, b" |> test_expr
        @test "import ModA.subModA: a, b.c" |> test_expr
        @test "import .ModA.subModA: a, b.c" |> test_expr
        @test "import ..ModA.subModA: a, b.c" |> test_expr
    end
    @testset "Export " begin
        @test "export ModA" |> test_expr
        @test "export a, b, c" |> test_expr
    end
end

@testset "Generators" begin
    @test "(y for y in X)" |> test_expr
    @test "((x,y) for x in X, y in Y)" |> test_expr
    @test "(y.x for y in X)" |> test_expr
    @test "((y) for y in X)" |> test_expr
    @test "(y,x for y in X)" |> test_expr
    @test "((y,x) for y in X)" |> test_expr
    @test "[y for y in X]" |> test_expr
    @test "[(y) for y in X]" |> test_expr
    @test "[(y,x) for y in X]" |> test_expr
    @test "Int[y for y in X]" |> test_expr
    @test "Int[(y) for y in X]" |> test_expr
    @test "Int[(y,x) for y in X]" |> test_expr
    @test """
    [a
    for a = 1:2]
    """ |> test_expr
    @test "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]" |> test_expr
    @test "all(d ≥ 0 for d in B.dims)" |> test_expr
end

@testset "Macros " begin
    @test "@mac" |> test_expr
    @test "@mac a b c" |> test_expr
    @test "@mac f(5)" |> test_expr
    @test "(@mac x)" |> test_expr
    @test "Mod.@mac a b c" |> test_expr
    # @test "[@mac a b]" |> test_expr
    @test "@inline get_chunks_id(i::Integer) = _div64(Int(i)-1)+1, _mod64(Int(i) -1)" |> test_expr
    @test "@inline f() = (), ()" |> test_expr
end

@testset "Square " begin
    @testset "vect" begin
        @test "[x]" |> test_expr
        @test "[(1,2)]" |> test_expr
        @test "[x...]" |> test_expr
        @test "[1,2,3,4,5]" |> test_expr
    end

    @testset "ref" begin
        @test "t[i]" |> test_expr
        @test "t[i, j]" |> test_expr
    end

    @testset "vcat" begin
        @test "[x;]" |> test_expr
        @test "[x;y;z]" |> test_expr
        @test """[x
                  y
                  z]""" |> test_expr
        @test """[x
                  y;z]""" |> test_expr
        @test """[x;y
                  z]""" |> test_expr
        @test "[x,y;z]" |> test_expr
    end

    @testset "typed_vcat" begin
        @test "t[x;]" |> test_expr
        @test "t[x;y]" |> test_expr
        @test """t[x
                   y]""" |> test_expr
        @test "t[x;y]" |> test_expr
        @test "t[x y; z]" |> test_expr
        @test "t[x, y; z]" |> test_expr
    end

    @testset "hcat" begin
        @test "[x y]" |> test_expr
    end

    @testset "typed_hcat" begin
        @test "t[x y]" |> test_expr
    end

    @testset "Comprehension" begin
        @test "[i for i = 1:10]" |> test_expr
        @test "Int[i for i = 1:10]" |> test_expr
    end
end


@testset "Keyword Blocks" begin
    @testset "If" begin
        @test "if cond end" |> test_expr
        @test "if cond; a; end" |> test_expr
        @test "if cond a; end" |> test_expr
        @test "if cond; a end" |> test_expr
        @test """if cond
            1
            1
        end""" |> test_expr
        @test """if cond
        else
            2
            2
        end""" |> test_expr
        @test """if cond
            1
            1
        else
            2
            2
        end""" |> test_expr
        @test "if 1<2 end" |> test_expr
        @test """if 1<2
            f(1)
            f(2)
        end""" |> test_expr
        @test """if 1<2
            f(1)
        elseif 1<2
            f(2)
        end""" |> test_expr
        @test """if 1<2
            f(1)
        elseif 1<2
            f(2)
        else
            f(3)
        end""" |> test_expr
        @test "if cond a end" |> test_expr
    end


    @testset "Try" begin
        @test "try f(1) end" |> test_expr
        @test "try; f(1) end" |> test_expr
        @test "try; f(1); end" |> test_expr
        @test "try; f(1); catch e; e; end" |> test_expr
        @test "try; f(1); catch e; e end" |> test_expr
        @test "try; f(1); catch e e; end" |> test_expr
        @test """try
            f(1)
        catch 
        end""" |> test_expr
        @test """try
            f(1)
        catch 
            error(err)
        end""" |> test_expr
        @test """try
            f(1)
        catch err
            error(err)
        end""" |> test_expr
        @test """try
            f(1)
        catch 
            error(err)
        finally
            stop(f)
        end""" |> test_expr
        @test """try
            f(1)
        catch err
            error(err)
        finally
            stop(f)
        end""" |> test_expr
        @test """try
            f(1)
        finally
            stop(f)
        end""" |> test_expr
    end
    @testset "For" begin
        @test """for i = 1:10
            f(i)
        end""" |> test_expr
        @test """for i = 1:10, j = 1:20
            f(i)
        end""" |> test_expr
    end

    @testset "Let" begin
        @test """let x = 1
            f(x)
        end""" |> test_expr
        @test """let x = 1, y = 2
            f(x)
        end""" |> test_expr
    end

    @testset "Do" begin
        @test """f(X) do x
            return x
        end""" |> test_expr
        @test """f(X,Y) do x,y
            return x,y
        end""" |> test_expr
    end
end

@testset "No longer broken things" begin
    @test "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]" |> test_expr
    @test "all(d ≥ 0 for d in B.dims)" |> test_expr
    @test ":(=)" |> test_expr
    @test ":(1)" |> test_expr
    @test ":(a)" |> test_expr
    @test "\"dimension \$d is not 1 ≤ \$d ≤ \$nd\" " |> test_expr
    @test "(@_inline_meta(); f(x))" |> test_expr
    @test "isa(a,b) != c" |> test_expr
    @test "isa(a,a) != isa(a,a)" |> test_expr
    @test "@mac return x" |> test_expr
    @test "ccall(:gethostname, stdcall, Int32, ())" |> test_expr
    @test "a,b," |> test_expr
    @test "m!=m" |> test_expr
    @test """
    ccall(:jl_finalize_th, Void, (Ptr{Void}, Any,),
                Core.getptls(), o)
    """ |> test_expr
    @test "\$(x...)" |> test_expr
    @test "(Base.@_pure_meta;)" |> test_expr
    @test "@inbounds @ncall a b c" |> test_expr
    @test "(Base.@_pure_meta;)" |> test_expr
    @test "@M a b->(@N c = @O d e f->g)" |> test_expr
    @test "4x/y" |> test_expr
    @test """
    A[if n == d
        i
    else
        (indices(A,n) for n = 1:nd)
    end...]
    """ |> test_expr
    @test """Base.@__doc__(bitstype \$(sizeof(basetype) * 8) \$(esc(typename)) <: Enum{\$(basetype)})""" |> test_expr
    @test """
    @spawnat(p,
        let m = a
            isa(m, Exception) ? m : nothing
        end)
    """ |> test_expr
    @test "[@spawn f(R, first(c), last(c)) for c in splitrange(length(R), nworkers())]" |> test_expr
    @test "M.:(a)" |> test_expr
    @test "-(-x)^1" |> test_expr
    @test "f(a for a in A if cond)" |> test_expr
    @test "M.r\"str\" " |> test_expr
    @test "! = f" |> test_expr
    @test """
            begin
                for i in I for j in J
                    if cond
                        a
                    end
                end end
            end""" |> test_expr
    @test "-f.(a.b + c)" |> test_expr
    @test ":(import Base: @doc)" |> test_expr
    @test "a.\$(b)" |> test_expr
    @test "a.\$f()" |> test_expr
    @test "[a for a in A for b in B]" |> test_expr
    @test "[a=>1, b=>2]" |> test_expr
    @test """@testset a for t in T
        t
    end""" |> test_expr
    @test "(-, ~)" |> test_expr
    @test "import Base.==" |> test_expr
    @test "(a+b)``" |> test_expr
    @test "a`text`" |> test_expr
    @test "a``" |> test_expr
    @test "a`text`b" |> test_expr
    @test "[a; a 0]" |> test_expr
    @test "[a, b; c]" |> test_expr
    @test "t{a; b} " |> test_expr
    @test "a ~ b + c -d" |> test_expr
    @test "y[j=1:10,k=3:2:9; isodd(j+k) && k <= 8]" |> test_expr
    @test "+(a,b,c...)" |> test_expr
    @test "(8=>32.0, 12=>33.1, 6=>18.2)" |> test_expr
    @test "(a,b = c,d)" |> test_expr
end

@testset "Broken things" begin
    @test_broken "@assert .!(isna(res[2]))" |> test_expr
    
    @test_broken "function(f, args...; kw...) end" |> test_expr
    @test_broken """
        "\\\\\$ch"
        """ |> test_expr
    @test_broken """
        if j+k <= deg +1
        end
        """ |> test_expr
    @test_broken "\$(a) * -\$(b)" |> test_expr
    @test_broken "function f() ::TensorShape end" |> test_expr
    @test_broken "-((attr.rise / PANGO_SCALE)pt).value" |> test_expr
    @test_broken "import Base: +, -, .+, .-" |> test_expr
    @test_broken "-3exp(im * d.μ * t) * (cos(a) - sin(a) / a) / a^2" |> test_expr
    @test_broken "" |> test_expr
    @test_broken "" |> test_expr
    @test_broken "" |> test_expr
end
