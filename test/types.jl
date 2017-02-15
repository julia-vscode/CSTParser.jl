facts("abstract defs") do
    strs =  ["abstract t"
            "abstract t{T}"
            "abstract t <: S"
            "abstract t{T} <: S"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

facts("bitstype defs") do
    strs =  ["bitstype 64 Int"
            "bitstype 4*16 Int"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

facts("typealias defs") do
    strs =  ["typealias name fsd"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

facts("type definitions") do
    strs =  ["type a end"
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
            end"""
             """type a <: Int
                c::Vector{Int}
             end"""]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end