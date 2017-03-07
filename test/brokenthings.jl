facts("broken things") do
    strs = [
            "iserr, lasterr = false, ((), nothing)"

            "-1"

            """
            for a in b
            end
            """

            """
            "\r\n" 
            """
            ]
    for str in strs
        test_parse(str)
    end
end

