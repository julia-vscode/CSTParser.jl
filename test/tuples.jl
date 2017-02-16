facts("tuples") do
    strs = ["1,",
            "1,2",
            "1,2,3",
            "()",
            "(==)",
            "(1)",
            "(1,)",
            "(1,2)",
            "(a,b,c)",
            "(a...)",
            "((a,b)...)",
            "a,b = c,d",
            "(a,b = c,d)",
            "(a,b = c,d)",
            "(a,b) = (c,d)"]
    for str in strs
        test_parse(str)
    end
end