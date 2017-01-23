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
for str in strs
    Parser.parse(str)
end
for str1 in strs
    for str2 in strs
        str = "$str1 + $str2"
        Parser.parse(str)
    end
end

randop() = rand(["+","-","*","/","^","|>","→",">>","<<",])
for n = 2:10
    for i = 1:50
        str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
        Parser.parse(str)
    end
end