@testitem "vect" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "[x]" |> test_expr
    @test "[(1,2)]" |> test_expr
    @test "[x...]" |> test_expr
    @test "[1,2,3,4,5]" |> test_expr
    # this is nonsensical, but iteration should still work
    @test traverse(CSTParser.parse(raw"""[[:alpha:]a←-]"""))
    # unterminated expressions may cause issues
    @test traverse(CSTParser.parse("bind_artifact!(\"../Artifacts.toml\",\"example\",hash,download_info=[(\"file://c:/juliaWork/tarballs/example.tar.gz\"\",tarball_hash)],force=true)\n2+2\n"))
    @test traverse(CSTParser.parse("[2+3+4"))
    @test traverse(CSTParser.parse("[2+3+4+"))
    @test traverse(CSTParser.parse("[\"hi\"\""))
    @test traverse(CSTParser.parse("[\"hi\"\"\n"))
    @test traverse(CSTParser.parse("[(1,2,3])"))

    @test "[2.0^53 2.0^53+2]" |> test_expr
end

@testitem "ref" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "t[i]" |> test_expr
    @test "t[i, j]" |> test_expr
end

@testitem "vcat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "[x;]" |> test_expr
    @test "[x;y;z]" |> test_expr
    @test """[x
          y
          z]""" |> test_expr
    @test """[x
          y;z]""" |> test_expr
    @test """[x;y
          z]""" |> test_expr
    @test "[x,y;z]" |> test_expr
    @test "[1,2;]" |> test_expr
end

@testitem "typed_vcat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "t[x;]" |> test_expr
    @test "t[x;y]" |> test_expr
    @test """t[x
           y]""" |> test_expr
    @test "t[x;y]" |> test_expr
    @test "t[x y; z]" |> test_expr
    @test "t[x, y; z]" |> test_expr
end

@testitem "ncat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.8-"
        @test "[;]" |> test_expr
        @test "[;;]" |> test_expr
        @test "[;;\n]" |> test_expr
        @test "[\n ;; \n]" |> test_expr
        @test "[;;;;;;;]" |> test_expr
        @test "[x;;;;;]" |> test_expr
        @test "[x;;]" |> test_expr
        @test "[x;; y;;    z]" |> test_expr
        @test "[x;;; y;;;z]" |> test_expr
        @test "[x;;; y;;;z]'" |> test_expr
        @test "[1 2; 3 4]" |> test_expr
        @test "[1;2;;3;4;;5;6;;;;9]" |> test_expr
        if VERSION > v"1.7-"
            @test "[let; x; end;; y]" |> test_expr
            @test "[let; x; end;;;; y]" |> test_expr
        end
    end
end

@testitem "typed_ncat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.8-"
        @test "t[;;]" |> test_expr
        @test "t[;;;;;;;]" |> test_expr
        @test "t[x;;;;;]" |> test_expr
        @test "t[x;;]" |> test_expr
        @test "t[x;; y;;    z]" |> test_expr
        @test "t[x;;; y;;;z]" |> test_expr
        @test "t[x;;\ny]" |> test_expr
        @test "t[x y;;\nz a]" |> test_expr
        @test "t[x y;;\nz a]'" |> test_expr
        @test "t[let; x; end;; y]" |> test_expr
        @test "t[let; x; end;;;; y]" |> test_expr
    end
end

@testitem "hcat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "[x y]" |> test_expr
    @test "[let; x; end y]" |> test_expr
    @test "[let; x; end; y]" |> test_expr
end

@testitem "typed_hcat" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "t[x y]" |> test_expr
    @test "t[let; x; end y]" |> test_expr
    @test "t[let; x; end; y]" |> test_expr
end

@testitem "Comprehension" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "[i for i = 1:10]" |> test_expr
    @test "Int[i for i = 1:10]" |> test_expr
    @test "[let;x;end for x in x]" |> test_expr
    @test "[let; x; end for x in x]" |> test_expr
    @test "[let x=x; x+x; end for x in x]" |> test_expr
    if v"1.7-" < VERSION < v"1.10-"
        @test """[
            [
                let l = min((d-k),k);
                    binomial(d-l,l);
                end; for k in 1:d-1
            ] for d in 2:9
        ]
        """ |> test_expr
    end
    if VERSION > v"1.10-"
        @test """[
            [
                let l = min((d-k),k);
                    binomial(d-l,l);
                end for k in 1:d-1
            ] for d in 2:9
        ]
        """ |> test_expr
    end
end
