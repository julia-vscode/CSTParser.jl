using CSTParser

function collect_bindings(x, out = String[])
    if x.binding != nothing
        push!(out, x.binding.name)
    end
    if (x.typ === CSTParser.BinaryOpCall && CSTParser.is_assignment(x) && !CSTParser.is_func_call(x)) || x.typ === CSTParser.Filter
        collect_bindings(x.args[3], out)
        collect_bindings(x.args[2], out)
        collect_bindings(x.args[1], out)
    elseif x.typ === CSTParser.WhereOpCall
        @inbounds for i = 3:length(x.args)
            collect_bindings(x.args[i], out)
        end
        collect_bindings(x.args[1], out)
        collect_bindings(x.args[2], out)
    elseif x.typ === CSTParser.Generator
        @inbounds for i = 2:length(x.args)
            collect_bindings(x.args[i], out)
        end
        collect_bindings(x.args[1], out)
    elseif x.args === nothing
    else
        @inbounds for a in x.args
            collect_bindings(a, out)
        end
    end
    return out
end


@test collect_bindings(CSTParser.parse("x = 1")) == ["x"]
@test collect_bindings(CSTParser.parse("(x) = 1")) == ["x"]
@test collect_bindings(CSTParser.parse("x, y =  1")) == ["x", "y"]
@test collect_bindings(CSTParser.parse("(x, y) =  1")) == ["x", "y"]
@test collect_bindings(CSTParser.parse("x = y =  1")) == ["y", "x"]
@test collect_bindings(CSTParser.parse("x::T = 1")) == ["x"]

@test collect_bindings(CSTParser.parse("f() = x")) == ["f"]
@test collect_bindings(CSTParser.parse("f(a) = x")) == ["f", "a"]
@test collect_bindings(CSTParser.parse("f(a) = x")) == ["f", "a"]
collect_bindings(CSTParser.parse("f(x::T) where {T <: S} where R = x")) == ["f", "R", "T","x"]
@test collect_bindings(CSTParser.parse("function f end")) == ["f"]
@test collect_bindings(CSTParser.parse("function f() end")) == ["f"]
@test collect_bindings(CSTParser.parse("function f() where T end")) == ["f", "T"]

@test collect_bindings(CSTParser.parse("macro m end")) == ["m"]
@test collect_bindings(CSTParser.parse("macro m() end")) == ["m"]

@test collect_bindings(CSTParser.parse("abstract type T end")) == ["T"]
@test collect_bindings(CSTParser.parse("abstract type T <: S end")) == ["T"]
@test collect_bindings(CSTParser.parse("abstract type T{S} end")) == ["T", "S"]

@test collect_bindings(CSTParser.parse("primitive type T 4 end")) == ["T"]
@test collect_bindings(CSTParser.parse("primitive type T <: S 4 end")) == ["T"]
@test collect_bindings(CSTParser.parse("primitive type T{S} 4 end")) == ["T", "S"]

@test collect_bindings(CSTParser.parse("struct T end")) == ["T"]
@test collect_bindings(CSTParser.parse("struct T <: S end")) == ["T"]
@test collect_bindings(CSTParser.parse("struct T{S} end")) == ["T" ,"S"]
@test collect_bindings(CSTParser.parse("struct T\nx end")) == ["T", "x"]
@test collect_bindings(CSTParser.parse("struct T\nT() = new()\n end")) == ["T", "T"]

@test collect_bindings(CSTParser.parse("mutable struct T end")) == ["T"]

@test collect_bindings(CSTParser.parse("for i = 1 end")) == ["i"]
@test collect_bindings(CSTParser.parse("let i = 1 end")) == ["i"]
@test collect_bindings(CSTParser.parse("[i for i = 1]")) == ["i"]
@test collect_bindings(CSTParser.parse("[i for i in 1]")) == ["i"]
@test collect_bindings(CSTParser.parse("try catch e end")) == ["e"]
@test collect_bindings(CSTParser.parse("map() do x end")) == ["x"]

@test collect_bindings(CSTParser.parse("(a,b)->x")) == ["a", "b"]
collect_bindings(CSTParser.parse("function f(a::T = 1) end")) == ["f", "a"]

let cst = CSTParser.parse("function a::T * b::T end")
    @test cst[2][1].binding !== nothing
    @test cst[2][3].binding !== nothing
end