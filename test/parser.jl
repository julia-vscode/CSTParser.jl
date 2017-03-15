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
        strs = ["a.b"
                "a.b.c"
                "(a(b)).c"
                "(a).(b).(c)"
                "(a).b.(c)"
                "(a).b.(c+d)"]
        for str in strs
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Dot Operator" begin
        for op in ["+", "-", "!", "~", "&", "::", "<:", ">:", "¬", "√", "∛", "∜"]
            x = Parser.parse("$op x")
            @test Expr(x) == remlineinfo!(Base.parse("$op x"))
        end
    end
end


@testset "Type Annotations" begin
    @testset "Curly" begin
        for str in  ["x{T}"
                    "x{T,S}"
                    """x{T,
                    S}"""
                    "a.b{T}"
                    "a(b){T}"
                    "(a(b)){T}"
                    "a{b}{T}"
                    "a{b}(c){T}"
                    "a{b}.c{T}"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end

@testset "Tuples" begin
    for str in [
                "1,",
                "1,2",
                "1,2,3",
                "()",
                "(==)",
                "(1)",
                "(1,)",
                "(1,2)",
                "(a,b,c)",
                "(a...)",
                "((a,b)...)",
                "a,b = c,d",
                "(a,b) = (c,d)"
                ]
        x = Parser.parse(str)
        @test Expr(x) == remlineinfo!(Base.parse(str))
    end
end

@testset "Function Calls" begin
    @testset "Simple Calls" begin
        for str in ["f(x)"
                    "f(x,y)"
                    "f(g(x))"
                    "f((x,y))"
                    "f((x,y), z)"
                    "f(z, (x,y), z)"
                    "f{a}(x)"
                    "f{a<:T}(x::T)"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Keyword Arguments" begin
        for str in ["f(x=1)"
                    "f(x=1,y::Int = 1)"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Compact Declaration" begin
        for str in ["f(x) = x"
                    "f(x) = g(x)"
                    "f(x) = (x)"
                    "f(x) = (x;y)"
                    "f(g(x)) = x"
                    "f(g(x)) = h(x)"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Standard Declaration" begin
        for str in ["function f end"

                    "function f(x) x end"

                    "function f(x); x; end"

                    "function f(x) x; end"

                    "function f(x); x end"

                    "function f(x) x;y end"
                    
                    """function f(x)
                        x
                    end
                    """

                    """function f(x,y =1)
                        x
                    end
                    """

                    """function f(x,y =1;z =2)
                        x
                    end
                    """
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
    @testset "Anonymous" begin
        for str in [
                    "x->y"
                    "(x,y)->x*y"
                    """
                    function ()
                        return 
                    end
                    """]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end





@testset "Types" begin
    @testset "Abstract" begin
        for str in ["abstract t"
                    "abstract t{T}"
                    "abstract t <: S"
                    "abstract t{T} <: S"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end


    @testset "Bitstype" begin
        for str in ["bitstype 64 Int"
                    "bitstype 4*16 Int"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Typealias" begin
        for str in ["typealias name fsd"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Structs" begin
        for str in ["type a end"
                    """type a
                        arg1
                    end"""
                    """type a <: T
                        arg1::Int
                        arg2::Int
                    end"""
                    """type a
                        arg1::T
                    end"""
                    """type a{T}
                        arg1::T
                        a(args) = new(args)
                    end"""
                    """type a <: Int
                        arg1::Vector{Int}
                    end"""
                    """immutable a <: Int
                        arg1::Vector{Int}
                    end"""]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end


@testset "Modules" begin
    @testset "Import/using " begin
        for str in ["import ModA"
                    "import .ModA"
                    "import ..ModA.a"
                    "import ModA.subModA"
                    "import ModA.subModA: a"
                    "import ModA.subModA: a, b"
                    "import ModA.subModA: a, b.c"
                    "import .ModA.subModA: a, b.c"
                    "import ..ModA.subModA: a, b.c"
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
    @testset "Export " begin
        for str in ["export ModA"
                    "export a, b, c"]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end

@testset "Generators" begin
    for str in ["(y for y in X)"
                "((x,y) for x in X, y in Y)"
                "(y.x for y in X)"
                "((y) for y in X)"
                "(y,x for y in X)"
                "((y,x) for y in X)"
                "[y for y in X]"
                "[(y) for y in X]"
                "[(y,x) for y in X]"
                "Int[y for y in X]"
                "Int[(y) for y in X]"
                "Int[(y,x) for y in X]"
                """
                [a
                for a = 1:2]
                """
                "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]"
                "all(d ≥ 0 for d in B.dims)"
                ]
        x = Parser.parse(str)
        @test Expr(x) == remlineinfo!(Base.parse(str))
    end
end

@testset "Macros " begin
    for str in  [
                "@mac"
                "@mac a b c"
                "@mac f(5)"
                "(@mac x)"
                "Mod.@mac a b c"
                # "[@mac a b]"
                "@inline get_chunks_id(i::Integer) = _div64(Int(i)-1)+1, _mod64(Int(i)-1)"
                "@inline f() = (), ()"
                ]
        x = Parser.parse(str)
        @test Expr(x) == remlineinfo!(Base.parse(str))
    end
end

@testset "Square " begin
    @testset "Vector" begin
        for str in  [
                    "[1,2,3,4,5]"
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Comprehension" begin
        for str in [
                    "[i for i = 1:10]"
                    "Int[i for i = 1:10]"
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Ref" begin
        for str in [
                    "x[i]"
                    "x[i + 1]"
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end


@testset "Keyword Blocks" begin
    @testset "If" begin
        for str in ["if a end"
                    """if a
                        1
                        1
                    end"""
                    """if a
                    else
                        2
                        2
                    end"""
                    """if a
                        1
                        1
                    else
                        2
                        2
                    end"""
                    "if 1<2 end"
                    """if 1<2
                        f(1)
                        f(2)
                    end"""
                    """if 1<2
                        f(1)
                    elseif 1<2
                        f(2)
                    end"""
                    """if 1<2
                        f(1)
                    elseif 1<2
                        f(2)
                    else
                        f(3)
                    end"""]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end


    @testset "Try" begin
        for str in ["try f(1) end"

                    """try
                        f(1)
                    catch 
                    end"""

                    """try
                        f(1)
                    catch 
                        error(err)
                    end"""

                    """try
                        f(1)
                    catch err
                        error(err)
                    end"""
                    
                    """try
                        f(1)
                    catch 
                        error(err)
                    finally
                        stop(f)
                    end"""

                    """try
                        f(1)
                    catch err
                        error(err)
                    finally
                        stop(f)
                    end"""

                    """try
                        f(1)
                    finally
                        stop(f)
                    end"""
                    ]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
    @testset "For" begin
        for str in ["""for i = 1:10
                        f(i)
                    end"""
                    """for i = 1:10, j = 1:20
                        f(i)
                    end"""]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Let" begin
        for str in  ["""let x = 1
                            f(x)
                        end"""
                    """let x = 1, y = 2
                            f(x)
                        end"""]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end

    @testset "Do" begin
        for str in ["""
                    f(X) do x
                        return x
                    end
                    """
                    """
                    f(X,Y) do x,y
                        return x,y
                    end
                    """]
            x = Parser.parse(str)
            @test Expr(x) == remlineinfo!(Base.parse(str))
        end
    end
end

@testset "No longer Broken things" begin
    for str in [
                "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]"
                "all(d ≥ 0 for d in B.dims)"
                ":(=)"
                ":(1)"
                ":(a)"
                "\"dimension \$d is not 1 ≤ \$d ≤ \$nd\" "

                "(@_inline_meta(); f(x))"
                "isa(a,b) != c"
                "isa(a,a) != isa(a,a)"
                "@mac return x"
                "ccall(:gethostname, stdcall, Int32, ())"
                "a,b,"
                "m!=m"
                """
                ccall(:jl_finalize_th, Void, (Ptr{Void}, Any,),
                         Core.getptls(), o)
                """
                "\$(x...)"
                "(Base.@_pure_meta;)"
                "@inbounds @ncall a b c"
                "(Base.@_pure_meta;)"
                "@M a b->(@N c = @O d e f->g)"
                "4x/y"
                """
                A[if n == d
                    i
                else
                    (indices(A,n) for n = 1:nd)
                end...]
                """
                """Base.@__doc__(bitstype \$(sizeof(basetype) * 8) \$(esc(typename)) <: Enum{\$(basetype)})"""
                ]
        x = Parser.parse(str)
        @test Expr(x) == remlineinfo!(Base.parse(str))
    end
end

@testset "Broken things" begin
    for str in [
                
                "(a,b = c,d)"
                "-(-x)^1"
                "[@spawn f(R, first(c), last(c)) for c in splitrange(length(R), nworkers())]"
                """
                @spawnat(p,
                    let m = a
                        isa(m, Exception) ? m : nothing
                    end)
                """
                ]
        x = Parser.parse(str)
        @test_broken Expr(x) == remlineinfo!(Base.parse(str))
    end
end
