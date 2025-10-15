# @testitem "Binary Operators" begin
    # using CSTParser: remlineinfo!
    # include("../shared.jl")

#     for iter = 1:25
#         println(iter)
#         str = join([["x$(randop())" for i = 1:19];"x"])

#         @test test_expr(str)
#     end
# end

@testitem "Conditional Operator" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("a ? b : c")
    @test test_expr("a ? b : c : d")
    @test test_expr("a ? b : c : d : e")
    @test test_expr("a ? b : c : d : e")
end


@testitem "Dot Operator" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "a.b" |> test_expr
    @test "a.b.c" |> test_expr
    @test "(a(b)).c" |> test_expr
    @test "(a).(b).(c)" |> test_expr
    @test "(a).b.(c)" |> test_expr
    @test "(a).b.(c+d)" |> test_expr
end

@testitem "Unary Operator" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "+" |> test_expr
    @test "-" |> test_expr
    @test "!" |> test_expr
    @test "~" |> test_expr
    @test "&" |> test_expr
    # @test "::" |> test_expr
    @test "<:" |> test_expr
    @test ">:" |> test_expr
    @test "¬" |> test_expr
    @test "√" |> test_expr
    @test "∛" |> test_expr
    @test "∜" |> test_expr

    @test "a=b..." |> test_expr
    @test "a-->b..." |> test_expr
    if VERSION >= v"1.6"
        @test "a<--b..." |> test_expr
        @test "a<-->b..." |> test_expr
    end
    @test "a&&b..." |> test_expr
    @test "a||b..." |> test_expr
    @test "a<b..." |> test_expr
    @test "a:b..." |> test_expr
    @test "a+b..." |> test_expr
    @test "a<<b..." |> test_expr
    @test "a*b..." |> test_expr
    @test "a//b..." |> test_expr
    @test "a^b..." |> test_expr
    @test "3a^b" |> test_expr
    @test "3//a^b" |> test_expr
    @test "3^b//a^b" |> test_expr
    @test "3^b//a" |> test_expr
    @test_broken "@a b ^ -c(d)^e" |> test_expr
    @test_broken "[a b ^ -c(d)^e f]" |> test_expr
    @test "a::b..." |> test_expr
    @test "a where b..." |> test_expr
    @test "a.b..." |> test_expr
end

@testitem "unary op calls" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "+(a,b)" |> test_expr
    @test "-(a,b)" |> test_expr
    @test "!(a,b)" |> test_expr
    @test "¬(a,b)" |> test_expr
    @test "~(a,b)" |> test_expr
    if VERSION > v"1.7-"
        @test "~(a)(foo...)" |> test_expr
        @test "~(&)(foo...)" |> test_expr
    end
    @test "<:(a,b)" |> test_expr
    @test "√(a,b)" |> test_expr
    @test "\$(a,b)" |> test_expr
    @test ":(a,b)" |> test_expr
    @test "&a" |> test_expr
    @test "&(a,b)" |> test_expr
    @test "::a" |> test_expr
    @test "::(a,b)" |> test_expr
end

@testitem "dotted non-calls" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "f(.+)" |> test_expr
    @test "f(.-)" |> test_expr
    @test "f(.!)" |> test_expr
    @test "f(.¬)" |> test_expr
    if VERSION >= v"1.6"
        @test_broken "f(.~)" |> test_expr_broken
    end
    @test "f(.√)" |> test_expr
    @test "f(:(.=))" |> test_expr
    @test "f(:(.+))" |> test_expr
    @test "f(:(.*))" |> test_expr
end


@testitem "comment parsing" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION >= v"1.6"
        @test "[1#==#2#==#3]" |> test_expr
        @test """
        begin
        arraycopy_common(false, LLVM.Builder(B), orig, origops[1], gutils)#=fwd=#
        return nothing
        end
        """ |> test_expr
        @test CSTParser.has_error(CSTParser.parse("""
        begin
        arraycopy_common(false, LLVM.Builder(B), orig, origops[1], gutils)#=fwd=#return nothing
        end
        """))
    end
end

@testitem "weird quote parsing" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test ":(;)" |> test_expr
    @test ":(;;)" |> test_expr
    @test ":(;;;)" |> test_expr
end

# In previous Julia versions, this errored during lowering. With JuliaSyntax, this is a parser error
if VERSION < v"1.10-"
    @testitem "parse const without assignment in quote" begin
        using CSTParser: remlineinfo!
        include("../shared.jl")

        @test ":(global const x)" |> test_expr
        @test ":(global const x::Int)" |> test_expr
        @test ":(const global x)" |> test_expr
        @test ":(const global x::Int)" |> test_expr
    end
end

@testitem "where precedence" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "a = b where c = d" |> test_expr
    @test "a = b where c" |> test_expr
    @test "b where c = d" |> test_expr
    @test "b where {c} == d" |> test_expr

    @test "a ? b where c : d" |> test_expr
    if VERSION >= v"1.6"
        @test "a --> b where c --> d" |> test_expr
        @test "a --> b where c" |> test_expr
        @test "b where c --> d" |> test_expr
        @test "b where c <-- d" |> test_expr
        @test "b where c <--> d" |> test_expr
    end

    @test "a || b where c || d" |> test_expr
    @test "a || b where c" |> test_expr
    @test "b where c || d" |> test_expr

    @test "a && b where c && d" |> test_expr
    @test "a && b where c" |> test_expr
    @test "b where c && d" |> test_expr

    @test "a <: b where c <: d" |> test_expr
    @test "a <: b where c" |> test_expr
    @test "b where c <: d" |> test_expr

    @test "a <| b where c <| d" |> test_expr
    @test "a <| b where c" |> test_expr
    @test "b where c <| d" |> test_expr

    @test "a : b where c : d" |> test_expr
    @test "a : b where c" |> test_expr
    @test "b where c : d" |> test_expr

    @test "a + b where c + d" |> test_expr
    @test "a + b where c" |> test_expr
    @test "b where c + d" |> test_expr

    @test "a << b where c << d" |> test_expr
    @test "a << b where c" |> test_expr
    @test "b where c << d" |> test_expr

    @test "a * b where c * d" |> test_expr
    @test "a * b where c" |> test_expr
    @test "b where c * d" |> test_expr

    @test "a // b where c // d" |> test_expr
    @test "a // b where c" |> test_expr
    @test "b where c // d" |> test_expr

    @test "a ^ b where c ^ d" |> test_expr
    @test "a ^ b where c" |> test_expr
    @test "b where c ^ d" |> test_expr

    @test "a :: b where c :: d" |> test_expr
    @test "a :: b where c" |> test_expr
    @test "b where c :: d" |> test_expr

    @test "a.b where c.d" |> test_expr
    @test "a.b where c" |> test_expr
    @test "b where c.d" |> test_expr

    @test "a where b where c" |> test_expr
end
