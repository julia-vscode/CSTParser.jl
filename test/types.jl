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
            end"""
            "x::Int"
             "x::Vector{Int}"
             "Vector{Int}"
             """type a <: Int
                c::Vector{Int}
             end"""]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end