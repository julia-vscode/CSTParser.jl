using FactCheck, Parser
for n in names(Parser, true, true)
    eval(:(import Parser.$n))
end
function remlineinfo!(x)
    if isa(x,Expr)
        id = find(map(x->isa(x,Expr) && x.head==:line,x.args))
        deleteat!(x.args,id)
        for j in x.args
            remlineinfo!(j)
        end
    end
    x
end

function printEXPR(io::IO, x::EXPR)
    for y in x
        if y isa EXPR
            printEXPR(io,y)
        else
            print(io,y.val)
            print(io,y.ws)
        end
    end
end

include("operators.jl")
include("functions.jl")
include("types.jl")
include("keywords.jl")


facts("misc reserved words") do
    strs =  ["const x = 3*5"
            "global i"
            """local i = x"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("tuples") do
    strs = ["a,b"
            "a,b,c"
            "a,b = c,d"
            "(a,b) = (c,d)"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("failing things") do
    strs = ["function f end"
            "(a,b = c,d)"
            "a ? b=c:d : e"]
    for str in strs
        @pending (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("generators") do
    strs = ["(y for y in X)"
            "((y) for y in X)"
            "(y,x for y in X)"
            "((y,x) for y in X)"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end



const examplemodule = readstring("fullspecexample.jl")

function timetest(n)
    for i =1:n
        Parser.parse(examplemodule)
    end
end

function timetest2(n)
    for i =1:n
        Base.parse(examplemodule)
    end
end

# using BenchmarkTools

timetest(1)
@timev timetest(10000)
# 2.74s/722mb
# 2.02s/493mb
# 2.02s/475mb
# 2.02s/430mb
# 2.02s/430mb
# 2.02s/414mb
# 1.96s/414mb
# @timev timetest2(10000)


if false
#     using ProfileView, BenchmarkTools
#     @benchmark timetest(10)
    Profile.clear()
    Profile.init(delay=0.0001)
    @profile timetest(1000)
    ProfileView.view()
end
