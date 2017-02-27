facts("macros") do
    strs = ["@mac f(5)"
            "(@mac x)"]
    for str in strs
        test_parse(str)
    end
end