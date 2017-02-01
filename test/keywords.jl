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
            end"""]
    for str in strs
        x = Parser.parse(str)
        @fact (x |> Expr) --> remlineinfo!(Base.parse(str))
        @fact x.loc.stop --> endof(str)
    end
end
