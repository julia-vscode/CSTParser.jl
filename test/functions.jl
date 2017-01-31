facts("one liner functions") do
    strs = ["f(x) = x"
            "f(x) = g(x)"
            "f(g(x)) = x"
            "f(g(x)) = h(x)"]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.loc.stop --> endof(str)
    end
end

facts("should fail to parse") do
    strs = ["f (x) = x"]
    for str in strs
        @fact (try Parser.parse(str) |> Expr catch e e.msg end) --> (try remlineinfo!(Base.parse(str)) catch e e.msg end)
    end
end

facts("function definitions") do
    strs =  ["""function f(x) x end"""
            """function f(x)
                x
            end"""
            "f(x::Int)"
             "f(x::Vector{Int})"
             "f(x::Vector{Vector{Int}})"
             "f(x::Vector{Vector{Int}})"]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.loc.stop --> endof(str)
    end
end