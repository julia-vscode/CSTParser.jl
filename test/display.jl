@testset "show" begin
    x = CSTParser.parse("a + (b*c) - d")
    @test sprint(show, x) === """
    0   13  13 | BinaryOpCall
    0   10  9  |  BinaryOpCall
    0   2   1  |   a
    2   2   1  |   OP: PLUS
    4   6   5  |   InvisBrackets
    4   1   1  |    (
    5   3   3  |    BinaryOpCall
    5   1   1  |     b
    6   1   1  |     OP: STAR
    7   1   1  |     c
    8   2   1  |    )
    10  2   1  |  OP: MINUS
    12  1   1  |  d
    """
end
