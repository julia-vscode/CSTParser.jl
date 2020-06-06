using CSTParser: @cst_str, headof, parentof, check_span
jl_parse(s) = CSTParser.remlineinfo!(Meta.parse(s))


function test_expr(s, head, n, endswithtrivia = false)
    x = CSTParser.parse(s)
    head === nothing || @test headof(x) === head
    @test length(x) === n
    @test x.args === nothing || all(x === parentof(a) for a in x.args)
    @test x.trivia === nothing || all(x === parentof(a) for a in x.trivia)
    @test Expr(x) == jl_parse(s)
    @test isempty(check_span(x))
    @test endswithtrivia ? (x.fullspan-x.span) == (last(x.trivia).fullspan - last(x.trivia).span) : (x.fullspan-x.span) == (last(x.args).fullspan - last(x.args).span)
end


@testset ":Local" begin
    test_expr("local a", :Local, 2) 
end

@testset ":Global" begin
    test_expr("global a", :Global, 2)
end

@testset ":Const" begin
    test_expr("const a = 1", :Const, 2)
end

@testset ":Return" begin
    test_expr("return a", :Return, 2)
end

@testset ":Abstract" begin
    test_expr("abstract type sig end", :Abstract, 4, true)
end

@testset ":Primitive" begin
    test_expr("primitive type sig spec end", :Primitive, 5, true)
end

@testset ":Call" begin
    test_expr("f()", :Call, 3, true)
    test_expr("f(a, b)", :Call, 6, true)
    test_expr("a + b", :Call, 3, false)
end

@testset ":Brackets" begin
    test_expr("(a)", :Brackets, 3, true)
end

@testset ":Begin" begin
    test_expr("begin end", :Block, 2, true)
    test_expr("begin a end", :Block, 3, true)
    test_expr("quote end", :Quote, 3, true)
    test_expr("while cond end", :While, 4, true)
    test_expr("for i = I end", :For, 4, true)
    test_expr("module m end", :Module, 5, true)
    test_expr("function f() end", :Function, 4, true)
    test_expr("macro f() end", :Macro, 4, true)
    test_expr("struct T end", :Struct, 5, true)
    test_expr("mutable struct T end", :Struct, 6, true)
end

@testset ":Export" begin
    test_expr("export a", :Export, 2, false)
    test_expr("export a, b", :Export, 4, false)
end

@testset ":Import" begin
    test_expr("import a", :Import, 2, false)
    test_expr("import a, b", :Import, 4, false)
    test_expr("import a.b", :Import, 2, false)
    test_expr("import a.b, c", :Import, 4, false)
    test_expr("import a:b", :Import, 2, false)
    test_expr("import a:b.c", :Import, 2, false)
    test_expr("import a:b.c, d", :Import, 2, false)
end

@testset ":Kw" begin
    test_expr("f(a=1)", :Call, 4, false)
end

@testset ":Tuple" begin
    test_expr("a,b ", :Tuple, 3, false)
    test_expr("(a,b) ", :Tuple, 5, true)
    test_expr("a,b,c ", :Tuple, 5, false)
    test_expr("(a,b),(c) ", :Tuple, 3, false)
end

@testset ":Curly" begin
    test_expr("x{a}", :Curly, 4, true)
    test_expr("x{a,b}", :Curly, 6, true)
end

@testset "operators" begin
    test_expr("!a", :Call, 2, false)
    test_expr("&a", nothing, 2, false)
    test_expr(":a", :Quotenode, 2, false)
    test_expr("a + 1", :Call, 3, false)
    test_expr(":(a + 1)", :Quote, 2, false)
    test_expr("a ? b : c", :If, 5, false)
    test_expr("a:b", :Call, 3, false)
    test_expr("a:b:c", :Call, 5, false)
    test_expr("a = b", nothing, 3, false)
    test_expr("a += b", nothing, 3, false)
    test_expr("a < b", :Call, 3, false)
    test_expr("a < b < c", :Comparison, 5, false)
    test_expr("a^b", :Call, 3, false)
    test_expr("!a^b", nothing, 2, false)
    test_expr("a.b", nothing, 3, false)
    test_expr("a.:b", nothing, 3, false)
    test_expr("a + b + c", :Call, 5, false)
    test_expr("a where b", :Where, 3, false)
    test_expr("a where {b }", :Where, 5, true)
    test_expr("a where {b,c }  ", :Where, 7, true)
    test_expr("a...", nothing, 2, false)
    @test let x = cst"a... "; x.fullspan - x.span == 1 end
    test_expr("a <: b", nothing, 3, false)
end

@testset ":Parameters" begin
    test_expr("f(a;b = 1)", nothing, 5, true)
end

@testset "lists" begin
    @testset ":Vect" begin
        test_expr("[]", :Vect, 2, true)
        test_expr("[a]", :Vect, 3, true)
        test_expr("[a, b]", :Vect, 5, true)
        test_expr("[a ]", :Vect, 3, true)
    end

    @testset ":Vcat" begin
        test_expr("[a\nb]", :Vcat, 4, true)
        test_expr("[a;b]", :Vcat, 4, true)
        test_expr("[a b\nc d]", :Vcat, 4, true)
        test_expr("[a\nc d]", :Vcat, 4, true) 
        test_expr("[a;c d]", :Vcat, 4, true) 
    end

    @testset ":Hcat" begin
        test_expr("[a b]", :Hcat, 4, true)
    end
    @testset ":Ref" begin
        test_expr("T[a]", :Ref, 4, true)
        test_expr("T[a,b]", :Ref, 6, true)
    end
    @testset ":Typed_Hcat" begin
        test_expr("T[a b]", :Typed_Hcat, 5, true)
    end
    @testset ":Typed_Hcat" begin
        test_expr("T[a;b]", :Typed_Vcat, 5, true)
    end
end

@testset ":Let" begin
    test_expr("let\n end", :Let, 4, true)
    test_expr("let x = 1 end", :Let, 4, true)
    test_expr("let x = 1, y =1  end", :Let, 4, true)
end

@testset ":Try" begin
    test_expr("try catch end", :Try, 6, true)
    test_expr("try a catch end", :Try, 6, true)
    test_expr("try catch e end", :Try, 6, true)
    test_expr("try a catch e end", :Try, 6, true)
    test_expr("try a catch e b end", :Try, 6, true)
    test_expr("try a catch e b end", :Try, 6, true)
    test_expr("try finally end", :Try, 7, true)
    test_expr("try finally a end", :Try, 7, true)
    test_expr("try a catch e b finally c end", :Try, 8, true)
end

@testset ":MacroCall" begin
    test_expr("@m", :MacroCall, 2, false)
    test_expr("@m a", :MacroCall, 3, false)
    test_expr("@m a b", :MacroCall, 4, false)
end

@testset ":If" begin
    test_expr("if c end", :If, 4, true)
    test_expr("if c a end", :If, 4, true)
    test_expr("if c a else end", :If, 6, true)
    test_expr("if c a else b end", :If, 6, true)
    test_expr("if c elseif c end", :If, 5, true)
    test_expr("if c a elseif c b end", :If, 5, true)
    test_expr("if c a elseif c b else d end", :If, 5, true)
end

@testset ":Do" begin
    test_expr("f() do x end", :Do, 4, true)
    test_expr("f() do x,y end", :Do, 4, true)
end

@testset ":String" begin
    test_expr("\"\$a\"", :String, 2, false)
    test_expr("\" \$a\"", :String, 3, false)
    test_expr("\" \$a \"", :String, 4, false)
end

@testset ":For" begin
    test_expr("for i = I end", :For, 4, true)
    test_expr("for i in I end", :For, 4, true)
    test_expr("for i ∈ I end", :For, 4, true)
    test_expr("for i ∈ I, j in J end", :For, 4, true)
end

@testset ":For" begin
    test_expr("\"doc\"\nT", :MacroCall, 4, false)
end

@testset ":Generator" begin
    test_expr("(arg for x in X)", :Brackets, 3, true)
    test_expr("(arg for x in X if x)", :Brackets, 3, true)
    test_expr("(arg for x in X, y in Y)", :Brackets, 3, true)
    test_expr("(arg for x in X, y in Y if x)", :Brackets, 3, true)
    test_expr("(arg for x in X for  y in Y)", :Brackets, 3, true)
    test_expr("(arg for x in X for  y in Y if x)", :Brackets, 3, true)
    test_expr("(arg for x in X for y in Y for z in Z)", :Brackets, 3, true) 
end

@testset ":CMD" begin
    let s = "``"
        x = CSTParser.parse(s)
        x1 = jl_parse(s)
        @test x1 == Expr(x)
    end
    let s = "`a`"
        x = CSTParser.parse(s)
        x1 = jl_parse(s)
        @test x1 == Expr(x)
    end
    test_expr("a``", nothing, 4, false)
end

s = "m.r\"s\""
CSTParser.parse(s) |> Expr |> dump
jl_parse(s) |> dump