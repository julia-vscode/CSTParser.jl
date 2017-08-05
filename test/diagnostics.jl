using Base.Test
using CSTParser
using CSTParser.Diagnostics: Diagnostic, ErrorCodes

using CSTParser.Diagnostics: UnexpectedInputEnd, UnexpectedOperator, UnexpectedIdentifier

function do_diag_test(text)
    ps = CSTParser.ParseState(text)
    CSTParser.parse(ps)
    ps.errored || error("Should have failed")
    ps.diagnostics
end

let diags = do_diag_test("abc(d")
#  none:1:6 ERROR: Unexpected end of input
#  abc(d
#       ^
# JuliaParser.jl did this, which might be more clear
#  none:1:6 error: Expected ')' or ','
#  abc(d
#       ^
#  none:1:4 note: to match '(' here
#  abc(d
#     ^
    @test length(diags) == 1
    @test diags[1] isa Diagnostic{UnexpectedInputEnd}
end

let diags = do_diag_test("a && && b")
#  none:1:6 ERROR: Unexpected operator
#  a && && b
#       ^~~
    @test diags[1] isa Diagnostic{CSTParser.Diagnostics.UnexpectedOperator}
end

let diags = do_diag_test("print x")
#  none:1:7 ERROR: Unexpected identifier
#  print x
#        ^
    @test diags[1] isa Diagnostic{UnexpectedIdentifier}
end

let diags = do_diag_test("a ? b c")
#  none:1:7 ERROR: Unexpected identifier
#  a ? b c
#        ^
#
# JuliaParser did this, which might be more clear
#  none:1:7 error: colon expected in "?" expression
#  a ? b c
#        ^
#  none:1:3 note: "?" was here
#  a ? b c
#    ^
    @test diags[1] isa Diagnostic{UnexpectedIdentifier}
end
