using CSTParser: @cst_str, headof, valof

@testitem "const local global return.local" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"local a = 1"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem "const local global return.global" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"global a = 1"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem "const local global return.global tuple" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"global (a = 1,b = 2)"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.trivia[3]
    @test x[5] === x.args[2]
    @test x[6] === x.trivia[4]
end

@testitem "const local global return.global tuple trailing comma" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"global (a = 1,b = 2,)"
    @test length(x) == 7
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.trivia[3]
    @test x[5] === x.args[2]
    @test x[6] === x.trivia[4]
    @test x[7] === x.trivia[5]
end

@testitem "const local global return.const" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"const a = 1"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end
@testitem "const local global return.simple" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"global const a = 1"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test length(x[2]) == 2
    @test x[2][1] === x.args[1].trivia[1]
    @test x[2][2] === x.args[1].args[1]
end

@testitem "const local global return.return" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"return a"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem "datatype declarations.abstract" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"abstract type T end"
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.trivia[3]
end

@testitem "datatype declarations.primitive" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"primitive type T N end"
    @test length(x) == 5
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]
end

@testitem "datatype declarations.struct" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"struct T body end"
    @test length(x) == 5
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]
end

@testitem "datatype declarations.mutable" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"mutable struct T body end"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.args[2]
    @test x[5] === x.args[3]
    @test x[6] === x.trivia[3]
end

@testitem "quote.block" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""quote
                    ex1
                    ex2
                end"""
    @test length(x) == 3
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
end

@testitem "quote.op" begin
    using CSTParser: @cst_str, headof, valof

    x = cst""":(body + 1)"""
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem "block.begin" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""begin
                    ex1
                    ex2
                end"""
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
end

@testitem ":for" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""for itr in itr
                    ex1
                    ex2
                end"""
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
end

@testitem ":outer" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""for outer itr in itr
                    ex1
                    ex2
                end""".args[1].args[1]
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end


@testitem "function.name only" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""function name end"""
    @test length(x) == 3
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
end

@testitem "function.full" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"""function sig()
                    ex1
                    ex2
                end"""
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
end

@testitem "braces.simple" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"{a,b,c}"
    @test length(x) == 7
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]
    @test x[6] === x.args[3]
    @test x[7] === x.trivia[4]
end

@testitem "braces.params" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"{a,b;c}"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[3]
    @test x[5] === x.args[1]
    @test x[6] === x.trivia[3]
end

@testitem "curly.simple" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"x{a,b}"
    @test length(x) == 6
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[3]
    @test x[6] === x.trivia[3]
end

@testitem "curly.params" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"x{a,b;c}"
    @test length(x) == 7
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[3]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[4]
    @test x[6] === x.args[2]
    @test x[7] === x.trivia[3]
end

@testitem ":comparison" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"a < b < c"
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.args[3]
    @test x[4] === x.args[4]
    @test x[5] === x.args[5]
end

@testitem "using.:using" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"using a"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]

    x = cst"using a, b, c"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]
    @test x[6] === x.args[3]

    x = cst"using .a"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]

    x = cst"using a: b, c"
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem "using.:" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"using a: b, c".args[1]
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.head
    @test x[3] === x.args[2]
    @test x[3] === x.args[2]
end

@testitem "using.." begin
    using CSTParser: @cst_str, headof, valof

    x = cst"using a".args[1]
    @test length(x) == 1
    @test x[1] === x.args[1]

    x = cst"using a.b".args[1]
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]

    x = cst"using ..a.b".args[1]
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.args[3]
    @test x[4] === x.trivia[1]
    @test x[5] === x.args[4]

    x = cst"using .a.b".args[1]
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[1]
    @test x[4] === x.args[3]

    x = cst"using ...a.b".args[1]
    @test length(x) == 6
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.args[3]
    @test x[4] === x.args[4]
    @test x[5] === x.trivia[1]
    @test x[6] === x.args[5]
end

@testitem ":kw" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"f(a=1)".args[2]
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
end

@testitem ":tuple" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"a,b"
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]

    x = cst"(a,b)"
    @test length(x) == 5
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]

    x = cst"(a,b,)"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]
    @test x[6] === x.trivia[4]
end

@testitem ":call" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"f()"
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.trivia[2]

    x = cst"f(a)"
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]

    x = cst"f(a,)"
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.trivia[3]

    x = cst"f(;)"
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]

    x = cst"f(a, b;c = 1)"
    @test length(x) == 7
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[3]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[4]
    @test x[6] === x.args[2]
    @test x[7] === x.trivia[3]

    x = cst"f(a, b,;c = 1)"
    @test length(x) == 8
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[3]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[4]
    @test x[6] === x.trivia[3]
    @test x[7] === x.args[2]
    @test x[8] === x.trivia[4]
end

@testitem ":where" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"a where {b,c;d}"
    @test length(x) == 8
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[3]
    @test x[6] === x.args[4]
    @test x[7] === x.args[2]
    @test x[8] === x.trivia[4]
end

@testitem ":quotenode" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"a.b".args[2]
    @test length(x) == 1
    @test x[1] === x.args[1]

    x = cst"a.:b".args[2]
    @test length(x) == 2
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
end

@testitem ":if" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"if cond end"
    @test length(x) == 4
    @test headof(x[1]) === :IF
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test headof(x[4]) === :END

    x = cst"if cond else end"
    @test length(x) == 6
    @test headof(x[1]) === :IF
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test headof(x[4]) === :ELSE
    @test x[5] === x.args[3]
    @test headof(x[6]) === :END

    x = cst"if cond args elseif a end"
    @test length(x) == 5
    @test headof(x[1]) === :IF
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test headof(x[4]) === :elseif
    @test headof(x[5]) === :END

    x = cst"a ? b : c"
    @test length(x) == 5
    @test valof(x[1]) === "a"
    @test CSTParser.isoperator(x[2])
    @test valof(x[3]) === "b"
    @test CSTParser.isoperator(x[4])
    @test valof(x[5]) === "c"
end

@testitem ":elseif" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"if cond elseif c args end".args[3]
    @test length(x) == 3
    @test headof(x[1]) === :ELSEIF
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]

    x = cst"if cond elseif c args else args end".args[3]
    @test length(x) == 5
    @test headof(x[1]) === :ELSEIF
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test headof(x[4]) === :ELSE
    @test x[5] === x.args[3]
end

@testitem ":string" begin
    using CSTParser: @cst_str, headof, valof, EXPR

    x = cst"\"txt$interp txt\""
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.args[3]

    x = cst"\"txt1 $interp1 txt2 $interp2 txt3\""
    @test length(x) == 7
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]
    @test x[6] === x.args[4]
    @test x[7] === x.args[5]

    x = cst"\"$interp\""
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.trivia[3]

    x = cst"\"$interp txt\""
    @test length(x) == 4
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.args[1]
    @test x[4] === x.args[2]

    x = cst"\"$(interp)\""
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.trivia[3]
    @test x[4] === x.args[1]
    @test x[5] === x.trivia[4]
    @test x[6] === x.trivia[5]

    x = cst"\"a$b$c \""
    @test length(x) == 6
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[3]

    x = cst"\"$(a)$(b)$(c)d\""
    @test length(x) == 14
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.trivia[3]
    @test x[4] === x.args[1]
    @test x[5] === x.trivia[4]
    @test x[6] === x.trivia[5]
    @test x[7] === x.trivia[6]
    @test x[8] === x.args[2]
    @test x[9] === x.trivia[7]
    @test x[10] === x.trivia[8]
    @test x[11] === x.trivia[9]
    @test x[12] === x.args[3]
    @test x[13] === x.trivia[10]
    @test x[14] === x.args[4]

    x = cst"""
    "$(()$)"
    """
    @test x[6] === x.trivia[5]

    x = cst"\"$(\"\")\""
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.trivia[2]
    @test x[3] === x.trivia[3]
    @test x[4] === x.args[1]
    @test x[5] === x.trivia[4]
    @test x[6] === x.trivia[5]

    x = EXPR(:string, EXPR[cst"\" \"", EXPR(:errortoken, 0, 0), EXPR(:errortoken, 0, 0)], EXPR[cst"$"])
    @test x[4] == x.args[3]
end

@testitem ":macrocall" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"@mac a"
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.args[3]

    x = cst"@mac(a)"
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[1]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]

    x = cst"@mac(a, b)"
    @test length(x) == 7
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[1]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]
    @test x[6] === x.args[4]
    @test x[7] === x.trivia[3]

    x = cst"@mac(a; b = 1)"
    @test length(x) == 6
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[1]
    @test x[4] === x.args[4]
    @test x[5] === x.args[3]
    @test x[6] === x.trivia[2]

    x = cst"@mac(a, b; x)"
    @test length(x) == 8
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
    @test x[3] === x.trivia[1]
    @test x[4] === x.args[4]
    @test x[5] === x.trivia[2]
    @test x[6] === x.args[5]
    @test x[7] === x.args[3]
    @test x[8] === x.trivia[3]
end

@testitem ":brackets" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"(x)"
    @test length(x) == 3
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
end

@testitem ":ref" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"x[i]"
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]

    x = cst"x[i, j]"
    @test length(x) == 6
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[3]
    @test x[6] === x.trivia[3]

    x = cst"x[i, j; k = 1]"
    @test length(x) == 7
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[3]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[4]
    @test x[6] === x.args[2]
    @test x[7] === x.trivia[3]
end

@testitem ":typed_vcat" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"x[i;j]"
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]
end

@testitem ":row" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"[a b; c d ]".args[1]
    @test length(x) == 2
    @test x[1] === x.args[1]
    @test x[2] === x.args[2]
end

@testitem ":module" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"module a end"
    @test length(x) == 5
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.args[2]
    @test x[4] === x.args[3]
    @test x[5] === x.trivia[2]
end

@testitem ":export" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"export a, b, c"
    @test length(x) == 6
    @test x[1] === x.trivia[1]
    @test x[2] === x.args[1]
    @test x[3] === x.trivia[2]
    @test x[4] === x.args[2]
    @test x[5] === x.trivia[3]
    @test x[6] === x.args[3]
end

if VERSION > v"1.11-"
    @testitem ":public" begin
        using CSTParser: @cst_str, headof, valof

        x = cst"public a, b, c"
        @test length(x) == 6
        @test x[1] === x.trivia[1]
        @test x[2] === x.args[1]
        @test x[3] === x.trivia[2]
        @test x[4] === x.args[2]
        @test x[5] === x.trivia[3]
        @test x[6] === x.args[3]
    end
end

@testitem ":parameters" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"f(a; b=1, c=1, d=1)"[4]
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[3]
end

@testitem "lowered iterator" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"for a in b end".args[1]
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
end

@testitem ":do" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"f(x) do arg something end"
    @test length(x) == 4
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
end

@testitem ":generator" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"(a for a in A)".args[1]
    @test length(x) == 3
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]

    x = cst"(a for a in A, b in B)".args[1]
    @test length(x) == 5
    @test x[1] === x.args[1]
    @test x[2] === x.trivia[1]
    @test x[3] === x.args[2]
    @test x[4] === x.trivia[2]
    @test x[5] === x.args[3]
end

@testitem ":flatten" begin
    using CSTParser: @cst_str, headof, valof

    function flatten(x)
        if length(x) == 0
            [x]
        else
            vcat([flatten(a) for a in x]...)
        end
    end
    function testflattenorder(s)
        x = CSTParser.parse(s)[2]
        issorted([Base.parse(Int, a.val) for a in flatten(x) if a.head === :INTEGER])
    end

    @test testflattenorder("(1 for 2 in 3)")
    @test testflattenorder("(1 for 2 in 3 for 4 in 5)")
    @test testflattenorder("(1 for 2 in 3, 4 in 5 for 6 in 7)")
    @test testflattenorder("(1 for 2 in 3 for 4 in 5, 6 in 7)")
    @test testflattenorder("(1 for 2 in 3 for 4 in 5, 6 in 7 if 8)")
end

@testitem ":filter" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"(a for a in A if a)".args[1].args[2]
    @test length(x) == 3
    @test valof(headof(x[1])) == "="
    @test headof(x[2]) === :IF
    @test valof(x[3]) == "a"
end

@testitem ":try" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"try expr catch e end"
    @test length(x) == 6
    @test headof(x[1]) === :TRY
    @test headof(x[2]) === :block
    @test headof(x[3]) === :CATCH
    @test valof(x[4]) == "e"
    @test headof(x[5]) === :block
    @test headof(x[6]) === :END

    x = cst"try expr finally expr2 end"
    @test length(x) == 8
    @test headof(x[1]) === :TRY
    @test headof(x[2]) === :block
    @test headof(x[3]) === :CATCH
    @test x[3].fullspan == 0
    @test headof(x[4]) === :FALSE
    @test headof(x[5]) === :FALSE
    @test headof(x[6]) === :FINALLY
    @test headof(x[7]) === :block
    @test headof(x[8]) === :END

    x = cst"try expr catch err finally expr3 end"
    @test length(x) == 8
    @test headof(x[1]) === :TRY
    @test headof(x[2]) === :block
    @test headof(x[3]) === :CATCH
    @test valof(x[4]) == "err"
    @test headof(x[5]) === :block
    @test headof(x[6]) === :FINALLY
    @test headof(x[7]) === :block
    @test headof(x[8]) === :END

    x = cst"try expr catch err expr2 finally expr3 end"
    @test length(x) == 8
    @test headof(x[1]) === :TRY
    @test headof(x[2]) === :block
    @test headof(x[3]) === :CATCH
    @test valof(x[4]) == "err"
    @test headof(x[5]) === :block
    @test headof(x[6]) === :FINALLY
    @test headof(x[7]) === :block
    @test headof(x[8]) === :END
end

@testitem ":comprehension" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"[a for a in A]"
    @test length(x) == 3
    @test headof(x[1]) === :LSQUARE
    @test headof(x[2]) === :generator
    @test headof(x[3]) === :RSQUARE
end

@testitem ":typed_comprehension" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"T[a for a in A]"
    @test length(x) == 4
    @test headof(x[1]) === :IDENTIFIER
    @test headof(x[2]) === :LSQUARE
    @test headof(x[3]) === :generator
    @test headof(x[4]) === :RSQUARE
end

@testitem "unary syntax" begin
    using CSTParser: @cst_str, headof, valof

    x = cst"<:a"
    @test length(x) == 2
    @test headof(x[1]) === :OPERATOR
    @test headof(x[2]) === :IDENTIFIER

    x = cst">:a"
    @test length(x) == 2
    @test headof(x[1]) === :OPERATOR
    @test headof(x[2]) === :IDENTIFIER

    x = cst"::a"
    @test length(x) == 2
    @test headof(x[1]) === :OPERATOR
    @test headof(x[2]) === :IDENTIFIER

    x = cst"&a"
    @test length(x) == 2
    @test headof(x[1]) === :OPERATOR
    @test headof(x[2]) === :IDENTIFIER

    x = cst"a..."
    @test length(x) == 2
    @test headof(x[1]) === :IDENTIFIER
    @test headof(x[2]) === :OPERATOR

    x = cst"$a"
    @test length(x) == 2
    @test headof(x[1]) === :OPERATOR
    @test headof(x[2]) === :IDENTIFIER
end
