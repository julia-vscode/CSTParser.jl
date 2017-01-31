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
Profile.clear()


n = 25
str = join([["$i $(randop()) " for i = 1:n-1];"$n"])
for i = 1:50
    Parser.parse(str)
end