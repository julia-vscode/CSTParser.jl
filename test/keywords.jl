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
            # """if true
            #     f(1)
            #     f(2)
            # else
            # end"""
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
            end"""
            """try
                f(1)
            catch err
                error(err)
            end"""]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.span --> endof(str)
        @fact ps.t.kind --> Tokenize.Tokens.END
    end
end



facts("import statements") do
    strs = ["import ModA"
            "import ModA.subModA"
            "import ModA.subModA: a"
            "import ModA.subModA: a, b, c"]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.span --> endof(str)
        @fact checkspan(x) --> true
    end
end

facts("export statements") do
    strs = ["export ModA"
            "export a, b, c"]
    for str in strs
        ps = Parser.ParseState(str)
        x = Parser.parse_expression(ps)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.span --> endof(str)
        @fact checkspan(x) --> true
    end
end

