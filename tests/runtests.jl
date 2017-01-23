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
    # for str1 in strs
    #     for str2 in strs
    #         str = "$str1 + $str2"
    #         @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
    #     end
    # end
end


facts("operators") do
    randop() = rand(["+","-","*","/","^"])
    for n = 2:4
        for i = 1:20
            str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
            @fact (Parser.parse(str) |> Expr) --> remlineinfo!(Base.parse(str))
        end
    end
end

if false
@benchmark Base.parse("1 + 2 - 3 * 4")
@benchmark parse("1 + 2 - 3 * 4")
end


parse("1 / 2 ^ 3 ^ 4") |> Expr
Base.parse("1 / 2 ^ 3 ^ 4")


args = [:+, :^ ,:*]

ret = Expr(:call, args[1], 1, 2)
lastcall = ret
    lastcall.args[end] = Expr(:call, args[2], lastcall.args[end], 3)
    lastcall = lastcall.args[end]

    lastcall.args[end] = Expr(:call, args[3], lastcall.args[end], 4)
    lastcall = lastcall.args[end]

    llastcall = copy(lastcall)
    empty!(lastcall.args)
    push!(lastcall.args, args[3])
    push!(lastcall.args, llastcall)
    push!(lastcall.args, 4)





ret = :(1/2^3)
lastcall = ret.args[3]
ret.args[3].args[end] = :(3^4)
ret