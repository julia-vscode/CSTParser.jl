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

function checkspan(x)
    if x isa EXPR
        cnt = 0
        for a in x
            checkspan(a)
        end
        @assert x.span == (length(x) == 0 ? 0 : sum(a.span for a in x)) "$(x.head)  $(x.span)  $(sum(a.span for a in x))"
    end
    true
end

function testfind(str)
    x = Parser.parse(str)
    for i = 1:sizeof(str)
        find(x, i)
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
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact sizeof(str) --> x.span
        @fact checkspan(x) --> true
    end
end

facts("tuples") do
    strs = ["1,",
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
            "(a,b = c,d)",
            "(a,b) = (c,d)"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end

facts("failing things") do
    strs = ["function f end"
            "(a,b = c,d)"
            "a ? b=c:d : e"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @pending Expr(io, x)  --> remlineinfo!(Base.parse(str))
    end
end

facts("generators") do
    strs = ["(y for y in X)"
            "((y) for y in X)"
            "(y,x for y in X)"
            "((y,x) for y in X)"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end

facts("macros") do
    strs = ["@time sin(5)"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x) --> remlineinfo!(Base.parse(str))
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
println(signif((@elapsed timetest2(500))/(@elapsed timetest(500)),3), "x speedup")

facts("fullspec") do
    x = Parser.parse(examplemodule)
    sizeof(examplemodule)
    @fact x.span --> sizeof(examplemodule)

end

function ttest3()
    totT = -Base.gc_time_ns()
    T1 =0 
    T2 =0 
    for i = 1:10000
        ps = ParseState(examplemodule)
        Parser.parse_expression(ps)
        T1+=ps.T1
        T2+=ps.T2
    end
    totT += Base.gc_time_ns()
    return T1/totT, T2/totT
end

