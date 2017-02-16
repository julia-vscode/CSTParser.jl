facts("macros") do
    strs = ["@time sin(5)"]
    for str in strs
        test_parse(str)
    end
end