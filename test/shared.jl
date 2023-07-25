using CSTParser: @cst_str, headof, parentof, check_span, EXPR, to_codeobject

jl_parse(s) = CSTParser.remlineinfo!(Meta.parse(s))

function check_parents(x::EXPR)
    if x.args isa Vector{EXPR}
        for a in x.args
            @test a.parent == x
            check_parents(a)
        end
    end
    if x.trivia isa Vector{EXPR}
        for a in x.trivia
            @test a.parent == x
        end
    end
end

function test_iter(ex)
    total = 0
    for x in ex
        @test x isa EXPR
        test_iter(x)
        total += x.fullspan
    end
    if length(ex) > 0
        @test total == ex.fullspan
    end
end

function test_expr(s, head, n, endswithtrivia = false)
    x = CSTParser.parse(s)
    head === nothing || @test headof(x) === head
    @test length(x) === n
    @test x.args === nothing || all(x === parentof(a) for a in x.args)
    @test x.trivia === nothing || all(x === parentof(a) for a in x.trivia)
    @test to_codeobject(x) == jl_parse(s)
    @test isempty(check_span(x))
    check_parents(x)
    test_iter(x)
    @test endswithtrivia ? (x.fullspan-x.span) == (last(x.trivia).fullspan - last(x.trivia).span) : (x.fullspan-x.span) == (last(x.args).fullspan - last(x.args).span)
end

randop() = rand(["-->", "→",
                 "||",
                 "&&",
                 "<", "==", "<:", ">:",
                 "<|", "|>",
                 ":",
                 "+", "-",
                 ">>", "<<",
                 "*", "/",
                 "//",
                 "^", "↑",
                 "::",
                 ".", "->"])

test_expr_broken(str) = test_expr(str, false)

function traverse(x)
    try
        for a in x
            @test traverse(a)
        end
        return true
    catch err
        @error "EXPR traversal failed." expr = x exception = err
        return false
    end
end

function test_expr(str, show_data=true)
    x, ps = CSTParser.parse(ParseState(str))

    x0 = to_codeobject(x)
    x1 = remlineinfo!(Meta.parse(str))

    @test x.args === nothing || all(x === parentof(a) for a in x.args)
    @test x.trivia === nothing || all(x === parentof(a) for a in x.trivia)
    @test isempty(check_span(x))
    check_parents(x)
    @test traverse(x)
    @test x.fullspan == sizeof(str)

    if CSTParser.has_error(ps) || x0 != x1
        if show_data
            println("Mismatch between flisp and CSTParser when parsing string $str")
            println("ParserState:\n $ps\n")
            println("CSTParser Expr:\n $x\n")
            println("Converted CSTParser Expr:\n $x0\n")
            println("Base EXPR:\n $x1\n")
        end
        return false
    end
    return true
end

function test_iter_spans(x)
    n = 0
    for i = 1:length(x)
        a  = x[i]
        if !(a isa EXPR)
            @info i, headof(x), to_codeobject(x)
        end
        @test a isa EXPR
        test_iter_spans(a)
        n += a.fullspan
    end
    length(x) > 0 && @test n == x.fullspan
end
