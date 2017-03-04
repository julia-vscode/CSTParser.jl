facts("vectors") do
    strs =  ["[1,2,3,4,5]"
            "[1,2+3,4 +5]"]
    for str in strs
        test_parse(str)
    end
end