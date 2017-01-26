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



facts("one liner functions") do
    strs = ["f(x) = x"
            "f(x) = g(x)"
            "f(g(x)) = x"
            "f(g(x)) = h(x)"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("should fail to parse") do
    strs = ["f (x) = x"]
    for str in strs
        @fact (try Parser.parse(str) |> Expr catch e e.msg end) --> (try remlineinfo!(Base.parse(str)) catch e e.msg end)
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
    randop() = rand(["→", "<", "==", "<|", "|>", "+", "-", ">>", "<<", "*", "/", "^", "↑"])
    n = 20
    for iter = 1:250
        str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("function definitions") do
    strs =  ["function f end"
            """function f(x) x end"""
            """function f(x)
                x
            end"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

facts("type definitions") do
    strs =  ["abstract name"
            "abstract name <: other"
            "abstract f(x+1)"
            "bitstype 64 Int"
            "bitstype 4*16 Int"
            "bitstype 4*16 f(x)"
            "typealias name fsd"
            "type a end"
            """type a
                arg1
            end"""
            """type a <: other
                arg1::Int
                arg2::Int
            end"""
            """type a{t}
                arg1::t
            end"""
            """type a{t}
                arg1::t
                a(args) = new(args)
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
             "f(x::Vector{Vector{Int}})"
             """type a <: Int
                c::Vector{Int}
             end"""]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end

# *** indicates Expr(op,....) rather than :call
precedence_list = [
#= RtoL       =#   #"=", "+=", # a=(b+=c) ***
#= RtoL       =#   #"?", # a?b:(c?d:e) *** (:if)
#= RtoL    X  =#   "||", # a||(b||c) ***
#= RtoL    X  =#   "&&", # a&&(b&&c) ***
#= RtoL    X  =#   #"-->", "→", # a-->(b→c) *** for --> only
#= chain   X  =#  "<","==", # :< and >: as head for 2 arg versions
#= LtoR    X  =#   "<|", "|>", # (a|>b)|>c
#= LtoR       =#   #":","..", # 3 arg version -> head=:(:), a,b,c
#= LtoR    X  =#   "+","-", # (a+b)-c
#= LtoR    X  =#   "<<",">>", # (a>>b)>>c
#= LtoR    X  =#   "*", "/", # (a*b)/c
#= LtoR    X  =#   "//", # (a//b)//c
#= RtoL    X  =#   "^","↑", # a^(b^c)
#= LtoR    X  =#   "::"] # (a::b)::c ***
#= LtoR       =#  # "."] # (a.b).c ***


facts("operators") do
    randop() = rand(precedence_list)
    for n = 2:10
        for i = 1:50
            str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
            @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
        end
    end
end





facts("positional information") do
    str = """
module ModuleName
const a = 16
typealias MyInt Int
bitstype a*4 SomeType

f(x) = x

function f end

function f(x::Int{T})
    while true
        f(x)
        while true
            break
        end
    end

    return x<4
end

type T <: Int
    a::Int
    b::Vector
end

baremodule SubModuleName
end

end
"""
ex = Parser.parse(str)
@fact span(ex) --> 305
@fact spanws(ex) --> 306
@fact span(ex.opener) --> 6
@fact spanws(ex.opener) --> 7
@fact span(ex.args[1]) --> 10
@fact spanws(ex.args[1]) --> 11
@fact span(ex.args[2].args[1]) --> 12
@fact spanws(ex.args[2].args[1]) --> 13
end
