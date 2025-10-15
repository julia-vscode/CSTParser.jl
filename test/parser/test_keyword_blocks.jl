@testitem "If" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

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


@testitem "Try" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    # @test "try f(1) end" |> test_expr
    # @test "try; f(1) end" |> test_expr
    # @test "try; f(1); end" |> test_expr
    @test "try; f(1); catch e; e; end" |> test_expr
    @test "try; f(1); catch e; e end" |> test_expr
    @test "try; f(1); catch e e; end" |> test_expr
    @test """
    try
        f(1)
    catch
    end
    """ |> test_expr
    @test """try
        f(1)
    catch
        error(err)
    end
    """ |> test_expr
    @test """
    try
        f(1)
    catch err
        error(err)
    end
    """ |> test_expr
    @test """
    try
        f(1)
    catch
        error(err)
    finally
        stop(f)
    end
    """ |> test_expr
    @test """
    try
        f(1)
    catch err
    finally
        stop(f)
    end
    """ |> test_expr
    @test """
    try
        f(1)
    catch err
        error(err)
    finally
        stop(f)
    end
    """ |> test_expr
    @test """try
        f(1)
    finally
        stop(f)
    end
    """ |> test_expr

    if VERSION > v"1.8-"
        @test """try
            f(1)
        catch
            x
        else
            stop(f)
        end
        """ |> test_expr
        @test """try
            f(1)
        catch
        else
            stop(f)
        end
        """ |> test_expr
        @test """try
            f(1)
        catch err
            x
        else
            stop(f)
        finally
            foo
        end
        """ |> test_expr
        # the most useless try catch ever:
        @test """try
        catch
        else
        finally
        end
        """ |> test_expr
    end
end
@testitem "For" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test """
    for i = 1:10
        f(i)
    end""" |> test_expr
    @test """
    for i = 1:10, j = 1:20
        f(i)
    end
    """ |> test_expr

    @testset "for outer parsing" begin
        @test "for outer i in 1:3 end" |> test_expr
        @test "for outer i = 1:3 end" |> test_expr
        if VERSION >= v"1.6"
            @test "for outer \$i = 1:3 end" |> test_expr
            if VERSION < v"1.12-"
                @test "for outer \$ i = 1:3 end" |> test_expr
            end
        end
    end
end

@testitem "Let" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test """
    let x = 1
        f(x)
    end
    """ |> test_expr
    @test """
    let x = 1, y = 2
        f(x)
    end
    """ |> test_expr
    @test """
    let
        x
    end
    """ |> test_expr
end

@testitem "Do" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test """f(X) do x
    return x
end""" |> test_expr
    @test """f(X,Y) do x,y
    return x,y
end""" |> test_expr
    @test "f() do x body end" |> test_expr
end

if VERSION > v"1.11-"
    @testitem "public" begin
        using CSTParser: remlineinfo!
        include("../shared.jl")

        @test "public foo" |> test_expr
        @test "public foo, bar" |> test_expr
        @test """
        public foo,
        bar
        """ |> test_expr
        @test "f() = public" |> test_expr
        @test "public(x) = 1" |> test_expr
        @test "public(x)" |> test_expr
        @test """
        let
            public
        end
        """ |> test_expr
    end
end
