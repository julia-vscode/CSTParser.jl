using FactCheck

include("/home/zac/github/Parser/src/Parser.jl")
for n in names(Parser, true, true)
    if !isdefined(Main, n)
        eval(:(import Parser.$n))
    end
end

str = "f(a,b,cd)"
x = Parser.parse(str)

facts("positional information") do
    @fact span(x) --> 9
    @fact span(opener(x)) --> 1
    @fact span(closer(x)) --> 2
end

str = """
module ModuleName

end
#comment"""
ex = Parser.parse(str)

facts("positional information string 1") do
    @fact span(ex) --> 22
    @fact spanws(ex) --> 31

    @fact span(opener(ex)) --> 6
    @fact spanws(opener(ex)) --> 7

    @fact span(closer(ex)) --> 3
    @fact spanws(closer(ex)) --> 12 
end

str = """
type TypeName <: TypeSuper
    a
    b::Int
    c::Vector{Int}
end"""
ex = Parser.parse(str)

facts("positional information string 2") do
    @fact span(ex) --> 66
    @fact spanws(ex) --> 66

    @fact span(opener(ex)) --> 4
    @fact spanws(opener(ex)) --> 5

    @fact span(closer(ex)) --> 3
    @fact spanws(closer(ex)) --> 12 
end
