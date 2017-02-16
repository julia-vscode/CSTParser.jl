facts("if blocks") do
    strs = ["if a end"
            """if a
                1
                1
            end"""
            """if a
            else
                2
                2
            end"""
            """if a
                1
                1
            else
                2
                2
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
        test_parse(str)
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
        test_parse(str)
    end
end

facts("misc reserved words") do
    strs =  ["const x = 3*5"
            "global i"
            """local i = x"""]
    for str in strs
        test_parse(str)
    end
end
