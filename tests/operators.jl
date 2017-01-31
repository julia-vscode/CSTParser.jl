using FactCheck

include("/home/zac/github/Parser/src/Parser.jl")
for n in names(Parser, true, true)
    if !isdefined(Main, n)
        eval(:(import Parser.$n))
    end
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

function printopchain(io::IO, x::EXPR)
    for y in x
        if y isa EXPR
            printopchain(io,y)
        else
            print(io,y.val)
            print(io,y.ws)
        end
    end
end

randop() = rand(["→", "<", "==", "<|", "|>", "+", "-", ">>", "<<", "*", "/", "^", "↑", "||", "&&", "<:",">:"])




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
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.loc.stop --> endof(str)
        @fact sprint(printopchain, x) --> str
    end
    for str1 in strs
        for str2 in strs
            str = "$str1 $(randop()) $str2"
            x = Parser.parse(str)
            @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
            @fact x.loc.stop --> endof(str)
            @fact sprint(printopchain, x) --> str
        end
    end
end

facts("operators") do
    n = 20
    for iter = 1:250
        str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.loc.stop --> endof(str)
        @fact sprint(printopchain, x) --> str
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
#= LtoR       =#   ":",#"..", # 3 arg version -> head=:(:), a,b,c
#= LtoR    X  =#   "+","-", # (a+b)-c
#= LtoR    X  =#   "<<",">>", # (a>>b)>>c
#= LtoR    X  =#   "*", "/", # (a*b)/c
#= LtoR    X  =#   "//", # (a//b)//c
#= RtoL    X  =#   "^","↑", # a^(b^c)
#= LtoR    X  =#   "::", # (a::b)::c ***
#= LtoR       =#   "."] # (a.b).c ***


facts("operators") do
    randop() = rand(precedence_list)
    for n = 2:10
        for i = 1:50
            str = join([["x$(randop())" for i = 1:n-1];"x"])
            x = Parser.parse(str)
            @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
            @fact x.loc.stop --> endof(str)
        end
    end
end

facts("? : syntax") do
    strs = ["a ? b : c"
            "a ? b:c : d"
            "a ? b:c : d:e"]
    for str in strs
        @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    end
end



