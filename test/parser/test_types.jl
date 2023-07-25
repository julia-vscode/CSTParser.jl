@testitem "Abstract" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")
    
    @test "abstract type t end" |> test_expr
    @test "abstract type t{T} end" |> test_expr
    @test "abstract type t <: S end" |> test_expr
    @test "abstract type t{T} <: S end" |> test_expr
end

@testitem "primitive" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")
    
    @test "primitive type Int 64 end" |> test_expr
    @test "primitive type Int 4*16 end" |> test_expr
end

@testitem "Structs" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")
    
    @test "struct a end" |> test_expr
    @test "struct a; end" |> test_expr
    @test "struct a; b;end" |> test_expr
    @test """struct a
        arg1
    end""" |> test_expr
    @test """struct a <: T
        arg1::Int
        arg2::Int
    end""" |> test_expr
    @test """struct a
        arg1::T
    end""" |> test_expr
    @test """struct a{T}
        arg1::T
        a(args) = new(args)
    end""" |> test_expr
    @test """struct a <: Int
        arg1::Vector{Int}
    end""" |> test_expr
    @test """mutable struct a <: Int
        arg1::Vector{Int}
    end""" |> test_expr
    if VERSION > v"1.8-"
        @test """mutable struct A
            const arg1::Vector{Int}
            arg2
        end""" |> test_expr
        @test """mutable struct A
            const arg1
            arg2
        end""" |> test_expr
        @test """struct A
            const arg1
            arg2
        end""" |> test_expr
        @test """@eval struct A
            const arg1
            arg2
        end""" |> test_expr
    end
end