@testset "show" begin
    x = CSTParser.parse("a + (b*c) - d")
    @test sprint(show, x) ===
    """
      1:13  BinaryOpCall
      1:10   BinaryOpCall
      1:2     a
      3:4     OP: PLUS
      5:10    InvisBrackets
      5:5      (
      6:8      BinaryOpCall
      6:6       b
      7:7       OP: STAR
      8:8       c
      9:10     )
     11:12   OP: MINUS
     13:13   d
    """
end
