randop() = rand(["-->", "→",
                 "||", 
                 "&&",
                 "<", "==", "<:", ">:",
                 "<|", "|>", 
                 ":",
                 "+", "-", 
                 ">>", "<<", 
                 "*", "/", 
                 "//",
                 "^", "↑",
                 "::",
                 "."])

facts("operators simple") do
    strs =  ["1 + 2 - 3"
             "1 * 2 / 3"
             "1 + 2 * 3"
             "1 * 2 + 3"
             "1 * 2 + 3"
             "1 + 2 - 3"
             "1 + 2 ^ 3"
             "1 ^ 2 + 3"
             "1 + 2 * 3 ^ 4"
             "1 ^ 2 + 3 * 4"
             "1 * 2 ^ 3 + 4"
             "1 ^ 2 * 3 + 4"
             "1 + 2 - 3 * 4"]
    for str1 in strs
        for str2 in strs
            str = "$str1$(randop())$str2"
            test_parse(str1)
            test_parse(str2)
            test_parse(str)
        end
    end
end



facts("non-assignment operators") do
    n = 20
    for iter = 1:250
        str = join([["x$(randop())" for i = 1:n-1];"x"])
        test_parse(str)
    end
end


facts("? : syntax") do
    strs = ["a ? b : c"
            "a ? b:c : d"
            "a ? b:c : d:e"]
    for str in strs
        x = Parser.parse(str)
        test_parse(str)
    end
end

facts("dot access") do
    strs = ["a.b"
            "a.b.c"
            "(a(b)).c"
            "(a).(b).(c)"
            "(a).b.(c)"
            "(a).b.(c+d)"]
    for str in strs
        test_parse(str)
    end
end

facts("unary") do
    ops = ["+", "-", "!", "~", "&", "::", "<:", ">:", "¬", "√", "∛", "∜"]
    for op in ops
        str = "$op b" 
        test_parse(str)
    end
end


