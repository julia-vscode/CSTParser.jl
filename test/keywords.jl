facts("if blocks") do
    strs = ["if true end"
            """if true
                f(1)
                f(2)
            end"""
            """if true
            else
                f(1)
                f(2)
            end"""
            """if true
                f(1)
                f(2)
            else
                f(1)
                f(2)
            end"""
            "if 1<2 end"
            """if 1<2
                f(1)
                f(2)
            end"""
            """if 1<2
                f(1)
            elseif 1<2
                f(2)
            end"""
            """if 1<2
                f(1)
            elseif 1<2
                f(2)
            else
                f(3)
            end"""]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact ps.t.kind --> Tokenize.Tokens.END "span mismatch for $str"
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

facts("try blocks") do
    strs = ["try f(1) end"
            """try
                f(1)
            catch err
                error(err)
            end"""]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact ps.t.kind --> Tokenize.Tokens.END "span mismatch for $str"
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end



facts("import statements") do
    strs = ["import ModA"
            "import ModA.subModA"
            "import ModA.subModA: a"
            "import ModA.subModA: a, b, c"
            "import ModA.subModA: a, b, c.d"]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

facts("export statements") do
    strs = ["export ModA"
            "export a, b, c"]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        io = IOBuffer(str)
        @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
        @fact checkspan(x) --> true "span mismatch for $str"
    end
end

