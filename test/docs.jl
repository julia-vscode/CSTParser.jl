facts("documetation") do
    str = """
    \"\"\"
    doc
    \"\"\"
    x
    """
    x = Parser.parse(str)
    io = IOBuffer(str)
    @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
    @fact checkspan(x) --> true "span mismatch for $str"

    str = """
    \"\"\"
    doc
    \"\"\"
    """
    x = Parser.parse(str)
    io = IOBuffer(str)
    @fact Expr(io, x)  --> remlineinfo!(Base.parse(str))
    @fact checkspan(x) --> true "span mismatch for $str"
end