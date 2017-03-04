facts("generators") do
    strs = ["(y for y in X)"
            "((x,y) for x in X, y in Y)"
            "(y.x for y in X)"
            "((y) for y in X)"
            "(y,x for y in X)"
            "((y,x) for y in X)"
            "[y for y in X]"
            "[(y) for y in X]"
            "[(y,x) for y in X]"
            "Int[y for y in X]"
            "Int[(y) for y in X]"
            "Int[(y,x) for y in X]"
            """
            [a
            for a = 1:2]
            """
            ]
    for str in strs
        test_parse(str)
    end
end
