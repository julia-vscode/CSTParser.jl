facts("calls") do
    strs = ["f(x)"
            "f(x,y)"
            "f(g(x))"
            "f((x,y))"
            "f((x,y), z)"
            "f(z, (x,y), z)"
            "f{a}(x)"
            "f{a<:T}(x::T)"]
    for str in strs
        test_parse(str)
    end
end

facts("kw args") do
    strs = ["f(x=1)"
            "f(x=1,y::Int = 1)"]
    for str in strs
        test_parse(str)
    end
end


facts("one liner functions") do
    strs = ["f(x) = x"
            "f(x) = g(x)"
            "f(g(x)) = x"
            "f(g(x)) = h(x)"]
    for str in strs
        test_parse(str)
    end
end

facts("function definitions") do
    strs =  ["function f end"
            "function f(x) x end"
            """function f(x)
                x
            end"""
            """function f(x::Int)
                x
            end"""
            """function f(x::Vector{Int})
                x
            end"""
            """function f(x,y =1)
                x
            end"""
            """function f(x,y =1;z =2)
                x
            end"""]
    for str in strs
        test_parse(str)
    end
end
