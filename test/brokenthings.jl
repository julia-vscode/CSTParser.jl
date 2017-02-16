facts("broken things") do
    strs = ["2(b)"
            "(x.x for x in X)"
            """
            for i = 1:2, j = 1:2
                f(i,j)
            end"""
            "import Base.@threads"
            "a ? b=c:d : e"
            """
            begin
                "doc"
                f(x) = x
            end"""
            "x+1 = 1"
            """@static if VERSION <= v"0.6.0-dev.2474"
                import Base: subtypes
                subtypes(m::Module, x::DataType) = x.abstract ? sort!(collect(_subtypes(m, x)), by=string) : DataType[]
            end"""
            ":(using \$s)"
            "[v[i]==Symbol(\"#unused#\") ? string(t[i]) : string(v[i])*\"::\"*string(t[i]) for i = 1:length(v)]"]
    for str in strs
        x = Parser.parse(str)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true
    end
end

