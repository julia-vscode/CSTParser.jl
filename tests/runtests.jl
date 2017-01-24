using FactCheck

include("/home/zac/github/Parser/src/Parser.jl")
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

testparse(str) = (Parser.parse(str) |> Expr) == remlineinfo!(Base.parse(str))

facts("one liner functions") do
    strs = ["f(x) = x"
            "f(x) = g(x)"
            "f(g(x)) = x"
            "f(g(x)) = h(x)"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end


facts("type defs") do
    strs = ["bitstype a b"
            "bitstype 32 Char"
            "bitstype 32 32"
            "typealias a b"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end



facts("operators") do
    strs =  ["1 + 2 - 3"
             "1 * 2 / 3"
             "1 + 2 * 3"
             "1 * 2 + 3"
             "1 * 2 + 3"
             "1 + 2 - 3"
             "1 + 2 ^ 3"
             "1 ^ 2 + 3"
             "1 + 2 * 3 ^ 4"
             "1 ^ 2 + 3 * 4"
             "1 * 2 ^ 3 + 4"
             "1 ^ 2 * 3 + 4"
             "1 + 2 - 3 * 4"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
    for str1 in strs
        for str2 in strs
            str = "$str1 + $str2"
            @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
        end
    end
end


facts("operators") do
    randop() = rand(["+","-","*","/","^","|>","→",">>","<<",])
    for n = 2:10
        for i = 1:50
            str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
            @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
        end
    end
end

facts("function definitions") do
    strs =  ["f(x) = x"
            "function f end"
            """function f(x)
                g(x) = x
                return g(x)
            end"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end


facts("misc reserved words") do
    strs =  ["const x = 3*5"
            "global i"
            """local i = x"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("type annotations") do
    strs =  ["x::Int"
             "x::Vector{Int}"
             "Vector{Int}"
             "f(x::Int)"
             "f(x::Vector{Int})"
             "f(x::Vector{Vector{Int}})"
             """type a 
                c::Vector{Int}
             end"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end



#=
assignment
conditional
lazyor : rtol
lazyand : rtol 
arrow : rtol
comparison : chain
pipe : ltor
colon : ltor
plus : chain
bits : ltor
times : chain
rational : ltor
power : ltor
decl : ltor
dots
    =#

# f(g(x) = x) should fail