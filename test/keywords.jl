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
            catch 
            end"""

            """try
                f(1)
            catch 
                error(err)
            end"""

            """try
                f(1)
            catch err
                error(err)
            end"""
            
            """try
                f(1)
            catch 
                error(err)
            finally
                stop(f)
            end"""

            """try
                f(1)
            catch err
                error(err)
            finally
                stop(f)
            end"""

            """try
                f(1)
            finally
                stop(f)
            end"""
            ]
    for str in strs
        test_parse(str)
    end
end

facts("for loops") do
    strs = ["""for i = 1:10
                f(i)
            end"""
            """for i = 1:10, j = 1:20
                f(i)
            end"""]
    for str in strs
        test_parse(str)
    end
end

facts("let blocks") do
    strs = ["""let x = 1
                    f(x)
                end"""
            """let x = 1, y = 2
                    f(x)
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
