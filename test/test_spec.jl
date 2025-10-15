@testitem ":local" begin
    include("shared.jl")

    test_expr("local a", :local, 2)
end

@testitem ":global" begin
    include("shared.jl")

    test_expr("global a", :global, 2)
    test_expr("global a, b", :global, 4)
    test_expr("global a, b = 2", :global, 2)
    test_expr("global const a = 1", :const, 2)
    test_expr("global const a = 1, b", :const, 2)
end

@testitem ":const" begin
    include("shared.jl")

    test_expr("const a = 1", :const, 2)
    test_expr("const global a = 1", :const, 2)
end

@testitem ":return" begin
    include("shared.jl")

    test_expr("return a", :return, 2)
end

@testitem ":abstract" begin
    include("shared.jl")

    test_expr("abstract type sig end", :abstract, 4, true)
end

@testitem ":primitive" begin
    include("shared.jl")

    test_expr("primitive type sig spec end", :primitive, 5, true)
end

@testitem ":call" begin
    include("shared.jl")

    test_expr("f()", :call, 3, true)
    test_expr("f(a, b)", :call, 6, true)
    test_expr("a + b", :call, 3, false)
end

@testitem ":brackets" begin
    include("shared.jl")

    test_expr("(a)", :brackets, 3, true)
end

@testitem ":begin" begin
    include("shared.jl")

    test_expr("begin end", :block, 2, true)
    test_expr("begin a end", :block, 3, true)
    test_expr("quote end", :quote, 3, true)
    test_expr("while cond end", :while, 4, true)
    test_expr("for i = I end", :for, 4, true)
    test_expr("module m end", :module, 5, true)
    test_expr("function f() end", :function, 4, true)
    test_expr("macro f() end", :macro, 4, true)
    test_expr("struct T end", :struct, 5, true)
    test_expr("mutable struct T end", :struct, 6, true)
end

@testitem ":export" begin
    include("shared.jl")

    test_expr("export a", :export, 2, false)
    test_expr("export a, b", :export, 4, false)
end

@testitem ":import" begin
    include("shared.jl")

    test_expr("import a", :import, 2, false)
    test_expr("import a, b", :import, 4, false)
    test_expr("import a.b", :import, 2, false)
    test_expr("import a.b, c", :import, 4, false)
    test_expr("import a:b", :import, 2, false)
    test_expr("import a:b.c", :import, 2, false)
    test_expr("import a:b.c, d", :import, 2, false)
end

@testitem ":kw" begin
    include("shared.jl")

    test_expr("f(a=1)", :call, 4, false)
    if VERSION <= v"1.12-"
        # currently broken due to JuliaSyntax inserting a begin-end block
        # on the RHS of the kwarg
        test_expr("f(::typeof(a)=1)", :call, 4, false)
    end
    test_expr("f(a::typeof(a)=1)", :call, 4, false)
    test_expr("f(::a=1)", :call, 4, false)
    test_expr("f(a::a=1)", :call, 4, false)

    test_expr("f(; a::typeof(a)=1)", :call, 4, false)
    test_expr("f(; a::a=1)", :call, 4, false)
end

@testitem ":tuple" begin
    include("shared.jl")

    test_expr("a,b ", :tuple, 3, false)
    test_expr("(a,b) ", :tuple, 5, true)
    test_expr("a,b,c ", :tuple, 5, false)
    test_expr("(a,b),(c) ", :tuple, 3, false)
end

@testitem ":curly" begin
    include("shared.jl")

    test_expr("x{a}", :curly, 4, true)
    test_expr("x{a,b}", :curly, 6, true)
end

@testitem "operators" begin
    include("shared.jl")

    test_expr("!a", :call, 2, false)
    test_expr("&a", nothing, 2, false)
    test_expr(":a", :quotenode, 2, false)
    test_expr("a + 1", :call, 3, false)
    test_expr(":(a + 1)", :quote, 2, false)
    test_expr("a ? b : c", :if, 5, false)
    test_expr("a:b", :call, 3, false)
    test_expr("a:b:c", :call, 5, false)
    test_expr("a = b", nothing, 3, false)
    test_expr("a += b", nothing, 3, false)
    test_expr("a < b", :call, 3, false)
    test_expr("a < b < c", :comparison, 5, false)
    test_expr("a^b", :call, 3, false)
    test_expr("!a^b", nothing, 2, false)
    test_expr("a.b", nothing, 3, false)
    test_expr("a.:b", nothing, 3, false)
    test_expr("a + b + c", :call, 5, false)
    test_expr("a where b", :where, 3, false)
    test_expr("a where {b }", :where, 5, true)
    test_expr("a where {b,c }  ", :where, 7, true)
    test_expr("a...", nothing, 2, false)
    @test let x = cst"a... "; x.fullspan - x.span == 1 end
    test_expr("a <: b", nothing, 3, false)

    # https://github.com/julia-vscode/CSTParser.jl/issues/278
    test_expr("*(a)*b*c", :call, 5, false)
    test_expr("+(a)+b+c", :call, 5, false)
    test_expr("(\na +\nb +\nc +\n d\n)", :brackets, 3, true)
end

@testitem ":parameters" begin
    include("shared.jl")

    test_expr("f(a;b = 1)", nothing, 5, true)
end

@testitem "lists :vect" begin
    include("shared.jl")

    test_expr("[]", :vect, 2, true)
    test_expr("[a]", :vect, 3, true)
    test_expr("[a, b]", :vect, 5, true)
    test_expr("[a ]", :vect, 3, true)
end

@testitem "lists :vcat" begin
    include("shared.jl")

    test_expr("[a\nb]", :vcat, 4, true)
    test_expr("[a;b]", :vcat, 4, true)
    test_expr("[a b\nc d]", :vcat, 4, true)
    test_expr("[a\nc d]", :vcat, 4, true)
    test_expr("[a;c d]", :vcat, 4, true)
end

@testitem "lists :hcat" begin
    include("shared.jl")

    test_expr("[a b]", :hcat, 4, true)
end

@testitem "lists :ref" begin
    include("shared.jl")

    test_expr("T[a]", :ref, 4, true)
    test_expr("T[a,b]", :ref, 6, true)
end

@testitem "lists :typed_hcat" begin
    include("shared.jl")

    test_expr("T[a b]", :typed_hcat, 5, true)
end

@testitem "lists :typed_vcat" begin
    include("shared.jl")

    test_expr("T[a;b]", :typed_vcat, 5, true)
end

@testitem ":let" begin
    include("shared.jl")

    test_expr("let\n end", :let, 4, true)
    test_expr("let x = 1 end", :let, 4, true)
    test_expr("let x = 1, y =1  end", :let, 4, true)
end

@testitem ":try" begin
    include("shared.jl")

    test_expr("try catch end", :try, 6, true)
    test_expr("try a catch end", :try, 6, true)
    test_expr("try catch e end", :try, 6, true)
    test_expr("try a catch e end", :try, 6, true)
    test_expr("try a catch e b end", :try, 6, true)
    test_expr("try a catch e b end", :try, 6, true)
    test_expr("try finally end", :try, 8, true)
    test_expr("try finally a end", :try, 8, true)
    test_expr("try a catch e b finally c end", :try, 8, true)
end

@testitem ":macrocall" begin
    include("shared.jl")

    test_expr("@m", :macrocall, 2, false)
    test_expr("@m a", :macrocall, 3, false)
    test_expr("@m a b", :macrocall, 4, false)
end

@testitem ":if" begin
    include("shared.jl")

    test_expr("if c end", :if, 4, true)
    test_expr("if c a end", :if, 4, true)
    test_expr("if c a else end", :if, 6, true)
    test_expr("if c a else b end", :if, 6, true)
    test_expr("if c elseif c end", :if, 5, true)
    test_expr("if c a elseif c b end", :if, 5, true)
    test_expr("if c a elseif c b else d end", :if, 5, true)
end

@testitem ":do" begin
    include("shared.jl")

    test_expr("f() do x end", :do, 4, true)
    test_expr("f() do x,y end", :do, 4, true)
end

@testitem "strings" begin
    include("shared.jl")

    test_expr("a\"txt\"", :macrocall, 3, false)
    test_expr("a\"txt\"b", :macrocall, 4, false)
end


@testitem ":string" begin
    include("shared.jl")

    test_expr("\"\$a\"", :string, 4, false)
    test_expr("\" \$a\"", :string, 4, false)
    test_expr("\" \$a \"", :string, 4, false)
end

@testitem ":for" begin
    include("shared.jl")

    test_expr("for i = I end", :for, 4, true)
    test_expr("for i in I end", :for, 4, true)
    test_expr("for i ∈ I end", :for, 4, true)
    test_expr("for i ∈ I, j in J end", :for, 4, true)
end

@testitem "docs" begin
    include("shared.jl")

    test_expr("\"doc\"\nT", :macrocall, 4, false)
end

@testitem ":generator" begin
    include("shared.jl")

    test_expr("(arg for x in X)", :brackets, 3, true)
    test_expr("(arg for x in X if x)", :brackets, 3, true)
    test_expr("(arg for x in X, y in Y)", :brackets, 3, true)
    test_expr("(arg for x in X, y in Y if x)", :brackets, 3, true)
    test_expr("(arg for x in X for  y in Y)", :brackets, 3, true)
    test_expr("(arg for x in X for  y in Y if x)", :brackets, 3, true)
    test_expr("(arg for x in X for y in Y for z in Z)", :brackets, 3, true)
end

@testitem ":cmd" begin
    include("shared.jl")

    let s = "``"
        x = CSTParser.parse(s)
        x1 = jl_parse(s)
        @test x1 == to_codeobject(x)
    end
    let s = "`a`"
        x = CSTParser.parse(s)
        x1 = jl_parse(s)
        @test x1 == to_codeobject(x)
    end
    let s = "`a \$a`"
        x = CSTParser.parse(s)
        x1 = jl_parse(s)
        @test x1 == to_codeobject(x)
    end
    test_expr("a``", nothing, 3, false)
    test_expr("a`a`", nothing, 3, false)
end

@testitem "macrocall" begin
    include("shared.jl")

    test_expr("@m", :macrocall, 2, false)
    test_expr("@m a", :macrocall, 3, false)
    test_expr("@m(a)", :macrocall, 5, false)
    test_expr("@horner(r) + r", nothing, 3, false)
end

@testitem "_str" begin
    include("shared.jl")

    test_expr("a\"txt\"", :macrocall, 3, false)
    test_expr("a.b\"txt\"", :macrocall, 3, false)
end
