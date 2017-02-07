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

function checkspan(x)
    if x isa EXPR
        cnt = 0
        for a in x
            checkspan(a)
        end
        @assert x.span == (length(x) == 0 ? 0 : sum(a.span for a in x))
    end
    true
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
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact sizeof(str) --> x.span
        @fact checkspan(x) --> true
    end
end

facts("tuples") do
    strs = ["a,b"
            "a,b,c"
            "a,b = c,d"
            "(a,b) = (c,d)"]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact sizeof(str) --> x.span
        @fact checkspan(x) --> true
    end
end

facts("failing things") do
    strs = ["function f end"
            "(a,b = c,d)"
            "a ? b=c:d : e"]
    for str in strs
        x = Parser.parse(str)
        @pending (x |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("generators") do
    strs = ["(y for y in X)"
            "((y) for y in X)"
            "(y,x for y in X)"
            "((y,x) for y in X)"]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
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
@timev timetest2(1000)

facts("fullspec") do
    x = Parser.parse(examplemodule)
    sizeof(examplemodule)
    @fact x.span --> sizeof(examplemodule)

end