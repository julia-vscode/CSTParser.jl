@testset "show" begin
    x = CSTParser.parse("a + (b*c) - d")
    @test sprint(show, x) ===
    """
      1:13  Call
      1:10   Call
      1:2     a
      3:4     OP: +
      5:10    InvisBrackets
      5:5      (
      6:8      Call
      6:6       b
      7:7       OP: *
      8:8       c
      9:10     )
     11:12   OP: -
     13:13   d
    """
end
