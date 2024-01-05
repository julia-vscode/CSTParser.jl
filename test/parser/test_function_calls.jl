@testitem "Simple Calls" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "f(x)" |> test_expr
    @test "f(x,y)" |> test_expr
    @test "f(g(x))" |> test_expr
    @test "f((x,y))" |> test_expr
    @test "f((x,y), z)" |> test_expr
    @test "f(z, (x,y), z)" |> test_expr
    @test "f{a}(x)" |> test_expr
    @test "f{a<:T}(x::T)" |> test_expr
end

@testitem "Keyword Arguments" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "f(x=1)" |> test_expr
    @test "f(x=1,y::Int = 1)" |> test_expr
end

@testitem "Compact Declaration" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "f(x) = x" |> test_expr
    @test "f(x) = g(x)" |> test_expr
    @test "f(x) = (x)" |> test_expr
    @test "f(x) = (x;y)" |> test_expr
    @test "f(g(x)) = x" |> test_expr
    @test "f(g(x)) = h(x)" |> test_expr
end

@testitem "Standard Declaration" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "function f end" |> test_expr
    @test "function f(x) x end" |> test_expr
    @test "function f(x); x; end" |> test_expr
    @test "function f(x) x; end" |> test_expr
    @test "function f(x); x end" |> test_expr
    @test "function f(x) x;y end" |> test_expr
    @test """function f(x) x end""" |> test_expr
    @test """function f(x,y =1) x end""" |> test_expr
    @test """function f(x,y =1;z =2) x end""" |> test_expr
end
@testitem "Anonymous" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "x->y" |> test_expr
    @test "(x,y)->x*y" |> test_expr
    @test """function ()
        return
    end""" |> test_expr
    @test """
    function (a,b)
        a+b
    end
    """ |> test_expr
    @test """
    function (a,b;c=2)
        a+b
    end
    """ |> test_expr
    @test """
    function (a,b;c)
        a+b
    end
    """ |> test_expr
    @test """
    function (;a,b=2)
        a+b
    end
    """ |> test_expr
    @test """
    function (b=2)
        a+b
    end
    """ |> test_expr
end
