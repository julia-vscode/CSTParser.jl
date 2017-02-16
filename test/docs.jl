facts("documetation") do
    str = """
    \"\"\"
    doc
    \"\"\"
    x
    """
    test_parse(str)

    str = """
    \"\"\"
    doc
    \"\"\"
    """
    test_parse(str)
end