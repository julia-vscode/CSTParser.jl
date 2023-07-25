@testitem "Imports " begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "import ModA" |> test_expr
    @test "import .ModA" |> test_expr
    @test "import ..ModA.a" |> test_expr
    @test "import ModA.subModA" |> test_expr
    @test "import ModA.subModA: a" |> test_expr
    @test "import ModA.subModA: a, b" |> test_expr
    @test "import ModA.subModA: a, b.c" |> test_expr
    @test "import .ModA.subModA: a, b.c" |> test_expr
    @test "import ..ModA.subModA: a, b.c" |> test_expr
end

@testitem "Export " begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "export ModA" |> test_expr
    @test "export a, b, c" |> test_expr
end
