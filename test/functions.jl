facts("function calls") do
    strs = ["f(x)"
            "f(x,y)"
            "f(g(x))"
            "f((x,y))"
            "f((x,y), z)"
            "f(z, (x,y), z)"
            "f{a}(x)"
            "f{a<:T}(x::T)"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end


facts("one liner functions") do
    strs = ["f(x) = x"
            "f(x) = g(x)"
            "f(g(x)) = x"
            "f(g(x)) = h(x)"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end

# facts("should fail to parse") do
#     strs = ["f (x) = x"]
#     for str in strs
#         @fact (try Parser.parse(str) |> Expr catch e e.msg end) --> (try remlineinfo!(Base.parse(str)) catch e e.msg end)
#     end
# end

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
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end