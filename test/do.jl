facts("do block") do
    strs = ["""
            f(X) do x
                return x
            end
            """
            """
            f(X,Y) do x,y
                return x,y
            end
            """]
    for str in strs
        test_parse(str)
    end
end