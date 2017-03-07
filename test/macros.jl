facts("macros") do
    strs = [
            "@mac a b c"
            "@mac f(5)"
            "(@mac x)"
            "Mod.@mac a b c"
            # "Mod.\$.@mac a b c"
            # "@Mod.mac a b"
            # "@Mod.mac a b"
            ]
    for str in strs
        test_parse(str)
    end
end