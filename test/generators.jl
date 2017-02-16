facts("generators") do
    strs = ["(y for y in X)"
            "((y) for y in X)"
            "(y,x for y in X)"
            "((y,x) for y in X)"]
    for str in strs
        test_parse(str)
    end
end
