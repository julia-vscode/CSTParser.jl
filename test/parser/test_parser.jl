@testitem "Parser" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test Meta.parse("(1,)") == Expr(:tuple, 1)
end

@testitem "Type Annotations Curly" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "x{T}" |> test_expr
    @test "x{T,S}" |> test_expr
    @test "a.b{T}" |> test_expr
    @test "a(b){T}" |> test_expr
    @test "(a(b)){T}" |> test_expr
    @test "a{b}{T}" |> test_expr
    @test "a{b}(c){T}" |> test_expr
    @test "a{b}.c{T}" |> test_expr
    @test """x{T,
S}""" |> test_expr
end

@testitem "Tuples" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @static if VERSION > v"1.1-"
        @test headof(CSTParser.parse("1,")) === :errortoken
    else
        @test "1," |> test_expr
    end
    @test "1,2" |> test_expr
    @test "1,2,3" |> test_expr
    @test "()" |> test_expr
    @test "(==)" |> test_expr
    @test "(1)" |> test_expr
    @test "(1,)" |> test_expr
    @test "(1,2)" |> test_expr
    @test "(a,b,c)" |> test_expr
    @test "(a...)" |> test_expr
    @test "((a,b)...)" |> test_expr
    @test "a,b = c,d" |> test_expr
    @test "(a,b) = (c,d)" |> test_expr
end

@testitem "Generators" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "(y for y in X)" |> test_expr
    @test "((x,y) for x in X, y in Y)" |> test_expr
    @test "(y.x for y in X)" |> test_expr
    @test "((y) for y in X)" |> test_expr
    @test "(y,x for y in X)" |> test_expr
    @test "((y,x) for y in X)" |> test_expr
    @test "[y for y in X]" |> test_expr
    @test "[(y) for y in X]" |> test_expr
    @test "[(y,x) for y in X]" |> test_expr
    @test "Int[y for y in X]" |> test_expr
    @test "Int[(y) for y in X]" |> test_expr
    @test "Int[(y,x) for y in X]" |> test_expr
    @test """
[a
for a = 1:2]""" |> test_expr
    @test "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]" |> test_expr
    @test "all(d ≥ 0 for d in B.dims)" |> test_expr
    @test "(arg for x in X)" |> test_expr
    @test "(arg for x in X for y in Y)" |> test_expr
    @test "(arg for x in X for y in Y for z in Z)" |> test_expr
    @test "(arg for x in X if A)" |> test_expr
    @test "(arg for x in X if A for y in Y)" |> test_expr
    @test "(arg for x in X if A for y in Y if B)" |> test_expr
    @test "(arg for x in X if A for y in Y for z in Z)" |> test_expr
    @test "(arg for x in X if A for y in Y if B for z in Z)" |> test_expr
    @test "(arg for x in X if A for y in Y if B for z in Z if C)" |> test_expr
    @test "(arg for x in X, y in Y for z in Z)" |> test_expr
    @test "(arg for x in X, y in Y if A for z in Z)" |> test_expr
end

@testitem "Macros " begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "macro m end" |> test_expr
    @test "macro m() end" |> test_expr
    @test "macro m() a end" |> test_expr
    @test "@mac" |> test_expr
    @test "@mac a b c" |> test_expr
    @test "@mac f(5)" |> test_expr
    @test "(@mac x)" |> test_expr
    @test "Mod.@mac a b c" |> test_expr
    @test "[@mac a b]" |> test_expr
    @test "@inline get_chunks_id(i::Integer) = _div64(Int(i)-1)+1, _mod64(Int(i) -1)" |> test_expr
    @test "@inline f() = (), ()" |> test_expr
    @test "@sprintf(\"%08d\", id)" |> test_expr
    @test "[@m @n a for a in A]" |> test_expr
    @test ":(@foo bar baz bat)" |> test_expr
    @test ":(@foo bar for i in j end)" |> test_expr
    @test "(@foo bar for i in j end)" |> test_expr
    @test "foo(@foo bar for i in j)" |> test_expr
    @test "foo.(@foo bar for i in j)" |> test_expr
    @test CSTParser.parse("@__DIR__\n\nx", true)[1].span == 8

    if VERSION >= v"1.8.0-"
        @test "M43018.@test43018() do; end" |> test_expr
        @test "@M43018.test43018() do; end" |> test_expr
    end
end

@testitem "Triple-quoted string" begin
    using CSTParser: remlineinfo!, valof
    include("../shared.jl")

    @test valof(CSTParser.parse("\"\"\" \" \"\"\"")) == " \" "
    @test valof(CSTParser.parse("\"\"\"a\"\"\"")) == "a"
    @test valof(CSTParser.parse("\"\"\"\"\"\"")) == ""
    @test valof(CSTParser.parse("\"\"\"\n\t \ta\n\n\t \tb\"\"\"")) == "a\n\nb"
    @test to_codeobject(CSTParser.parse("\"\"\"\ta\n\tb \$c\n\td\n\"\"\"")) == Expr(:string, "\ta\n\tb ", :c, "\n\td\n")
    @test to_codeobject(CSTParser.parse("\"\"\"\n\ta\n\tb \$c\n\td\n\"\"\"")) == Expr(:string, "\ta\n\tb ", :c, "\n\td\n")
    @test to_codeobject(CSTParser.parse("\"\"\"\n\ta\n\tb \$c\n\td\n\t\"\"\"")) == Expr(:string, "a\nb ", :c, "\nd\n")
    @test to_codeobject(CSTParser.parse("\"\"\"\n\t \ta\$(1+\n1)\n\t \tb\"\"\"")) == Expr(:string, "a", :(1 + 1), "\nb")
    ws = "                         "
    "\"\"\"\n$ws%rv = atomicrmw \$rmw \$lt* %0, \$lt %1 acq_rel\n$(ws)ret \$lt %rv\n$ws\"\"\"" |> test_expr
    ws1 = "        "
    ws2 = "    "
    "\"\"\"\n$(ws1)a\n$(ws1)b\n$(ws2)c\n$(ws2)d\n$(ws2)\"\"\"" |> test_expr
    "\"\"\"\n$(ws1)a\n\n$(ws1)b\n\n$(ws2)c\n\n$(ws2)d\n\n$(ws2)\"\"\"" |> test_expr
    @test "\"\"\"\n$(ws1)α\n$(ws1)β\n$(ws2)γ\n$(ws2)δ\n$(ws2)\"\"\"" |> test_expr
    @test "\"\"\"Float\$(bit)\"\"\"" |> test_expr
    @test headof(CSTParser.parse("\"\"\"abc\$(de)fg\"\"\"").args[3]) == :STRING
    @test headof(CSTParser.parse("\"\"\"abc(de)fg\"\"\"")) == :TRIPLESTRING
    @test "\"\"\"\n\t\"\"\"" |> test_expr # Change of behaviour from v1.5 -> v1.6
end

@testitem "raw strings with unicode" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test raw"""re = r"(\\"[^\\"]*\\")  (\d+) bytes α (\\"[^\\"]*\\")\\\\" """ |> test_expr
    @test raw"""re = r"(\\"[^\\"]*\\") ⋯ (\d+) bytes ⋯ (\\"[^\\"]*\\")" """ |> test_expr
end


@testitem "weird string edge cases" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.7-"
        @test """x = raw"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq" """ |> test_expr
        @test """x = "a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq" """ |> test_expr
        @test """x = raw\"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """x = \"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """x = @naah \"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """x = Foo.@naah \"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """x = Foo.@naah_str \"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """x = Foo.naah\"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\" """ |> test_expr
        @test """\"\"\"a \$(asd)  sd\\\n  bsf\\\\leq\n\\\\leq\"\"\"\nfoo""" |> test_expr
        @test """throw(ArgumentError("invalid \$(m == 2 ? "hex (\\\\x)" :
        "unicode (\\\$u)") escape sequence"))""" |> test_expr
        @test "\"a\\\\\\\\\\\nb\"" |> test_expr
        for c in 0:20
            @test test_expr(string("\"a", '\\'^c, "\nb\""))
            @test test_expr(string("\"\"\"a", '\\'^c, "\nb\"\"\""))
        end
        for c in 0:20
            @test test_expr(string("`a", '\\'^c, "\nb`"))
            @test test_expr(string("```a", '\\'^c, "\nb```"))
        end

        @test "\"\"\"\n    a\\\n  b\"\"\"" |> test_expr
        @test "\"\"\"\n        a\\\n  b\"\"\"" |> test_expr
        @test "\"\"\"\na\\\n  b\"\"\"" |> test_expr
        @test "\"\"\"\na\\\nb\"\"\"" |> test_expr
        @test "\"\"\"\n   a\\\n       b\"\"\"" |> test_expr
    end
end

@testitem "No longer broken things" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "[ V[j][i]::T for i=1:length(V[1]), j=1:length(V) ]" |> test_expr
    @test "all(d ≥ 0 for d in B.dims)" |> test_expr
    @test ":(=)" |> test_expr
    @test ":(1)" |> test_expr
    @test ":(a)" |> test_expr
    @test "(@_inline_meta(); f(x))" |> test_expr
    @test "isa(a,b) != c" |> test_expr
    @test "isa(a,a) != isa(a,a)" |> test_expr
    @test "@mac return x" |> test_expr
    @static if VERSION > v"1.1-"
        @test headof(CSTParser.parse("a,b,").trivia[2]) === :errortoken
    else
        @test "a,b," |> test_expr
    end
    @test "m!=m" |> test_expr
    @test "+(x...)" |> test_expr
    @test "+(promote(x,y)...)" |> test_expr
    @test "\$(x...)" |> test_expr
    @test "ccall(:gethostname, stdcall, Int32, ())" |> test_expr
    @test "@inbounds @ncall a b c" |> test_expr
    @test "(a+b)``" |> test_expr
    @test "(-, ~)" |> test_expr
    @test """function +(x::Bool, y::T)::promote_type(Bool,T) where T<:AbstractFloat
            return ifelse(x, oneunit(y) + y, y)
        end""" |> test_expr
    @test """finalizer(x,x::GClosure->begin
                ccall((:g_closure_unref,Gtk.GLib.libgobject),Void,(Ptr{GClosure},),x.handle)
            end)""" |> test_expr
    @test "function \$A end" |> test_expr
    @test "&ctx->exe_ctx_ref" |> test_expr
    @test ":(\$(docstr).\$(TEMP_SYM)[\$(key)])" |> test_expr
    @test "SpecialFunctions.\$(fsym)(n::Dual)" |> test_expr
    @test "(Base.@_pure_meta;)" |> test_expr
    @test "@M a b->(@N c = @O d e f->g)" |> test_expr
    @test "! = f" |> test_expr
    @test "[a=>1, b=>2]" |> test_expr
    @test "a.\$(b)" |> test_expr
    @test "a.\$f()" |> test_expr
    @test "4x/y" |> test_expr
    @test """
    ccall(:jl_finalize_th, Void, (Ptr{Void}, Any,),
            Core.getptls(), o)
    """ |> test_expr
    @test """
    A[if n == d
    i
    else
    (indices(A,n) for n = 1:nd)
    end...]
    """ |> test_expr
    @test """
    @spawnat(p,
    let m = a
        isa(m, Exception) ? m : nothing
    end)
    """ |> test_expr #
    @test "[@spawn f(R, first(c), last(c)) for c in splitrange(length(R), nworkers())]" |> test_expr
    @test "M.:(a)" |> test_expr
    @test """
        begin
            for i in I for j in J
                if cond
                    a
                end
            end end
        end""" |> test_expr
    @test "-f.(a.b + c)" |> test_expr
    @test ":(import Base: @doc)" |> test_expr
    @test "[a for a in A for b in B]" |> test_expr
    @test "+(a,b,c...)" |> test_expr
    @test """@testset a for t in T
    t
    end""" |> test_expr
    @test "import Base.==" |> test_expr
    @test "a`text`" |> test_expr
    @test "a``" |> test_expr
    @test "a`text`b" |> test_expr
    @test "[a; a 0]" |> test_expr
    @test "[a, b; c]" |> test_expr
    @test "t{a; b} " |> test_expr
    @test "a ~ b + c -d" |> test_expr
    @test "y[j=1:10,k=3:2:9; isodd(j+k) && k <= 8]" |> test_expr
    @test "(8=>32.0, 12=>33.1, 6=>18.2)" |> test_expr
    @test "(a,b = c,d)" |> test_expr
    @test "[ -1 -2;]" |> test_expr
    @test "-2y" |> test_expr # precedence
    @test "'''" |> test_expr # tokenize
    @test """
    if j+k <= deg +1
    end
    """ |> test_expr
    @test "function f() ::T end" |> test_expr # ws closer
    if VERSION > v"1.10-"
        # import Base: .+ is no longer valid with Julia 1.10
        @test "import Base: +, -" |> test_expr
    else
        @test "import Base: +, -, .+, .-" |> test_expr
    end
    if VERSION > v"1.6-"
        @test "import Base.:+" |> test_expr
        @test "import Base.:⋅" |> test_expr
        @test "import Base.:sin, Base.:-" |> test_expr
    end
    @test "[a +   + l]" |> test_expr # ws closer
    @test "@inbounds C[i,j] = - α[i] * αjc" |> test_expr
    @test "@inbounds C[i,j] = - n * p[i] * pj" |> test_expr
    @test """
    if ! a
        b
    end
    """ |> test_expr # ws closer
    @test "[:-\n:+]" |> test_expr
    @test "::a::b" |> test_expr
    @test "-[1:nc]" |> test_expr
    @test "@assert .!(isna(res[2]))" |> test_expr # v0.6
    @test "-((attr.rise / PANGO_SCALE)pt).value" |> test_expr
    @test "!(a = b)" |> test_expr
    @test "-(1)a" |> test_expr
    @test "!(a)::T" |> test_expr
    @test "a::b where T<:S" |> test_expr
    @test "+(x::Bool, y::T)::promote_type(Bool,T) where T<:AbstractFloat" |> test_expr
    @test "T where V<:(T where T)" |> test_expr
    @test "function ^(z::Complex{T}, p::Complex{T})::Complex{T} where T<:AbstractFloat end" |> test_expr
    @test "function +(a) where T where S end" |> test_expr
    @test "function -(x::Rational{T}) where T<:Signed end" |> test_expr
    @test "\$(a)(b)" |> test_expr
    @test "if !(a) break end" |> test_expr
    @test "module a() end" |> test_expr
    if VERSION > v"1.3-"
        @test """module var"#43932#" end""" |> test_expr
    end
    @test "M.r\"str\" " |> test_expr
    @test "f(a for a in A if cond)" |> test_expr
    @test "\"dimension \$d is not 1 ≤ \$d ≤ \$nd\" " |> test_expr
    @test "-(-x)^1" |> test_expr
    @test """
    "\\\\\$ch"
    """ |> test_expr
    @test "µs" |> test_expr # normalize unicode
    if VERSION >= v"1.10-"
        @test "ℏħ" |> test_expr # normalize unicode
    end
    @test """
    (x, o; p = 1) -> begin
        return o, p
    end
    """ |> test_expr # normalize unicode
    @test """
    (x, o...; p...) -> begin
        return o, p
    end
    """ |> test_expr # normalize unicode
    @test "function func() where {A where T} x + 1 end" |> test_expr # nested where
    @test "(;x)" |> test_expr # issue 39
    @test """
    let f = ((; a = 1, b = 2) -> ()),
        m = first(methods(f))
        @test DSE.keywords(f, m) == [:a, :b]
    end
    """ |> test_expr
    @test "-1^a" |> test_expr
    @test "function(f, args...; kw...) end" |> test_expr
    @test "function(f, args...=1; kw...) end" |> test_expr
    @test "2a * b" |> test_expr
    @test "(g1090(x::T)::T) where {T} = x+1.0" |> test_expr
    @test "(:) = Colon()" |> test_expr
    @test "a + in[1]" |> test_expr
    @test "function f(ex) +a end" |> test_expr
    @test "x`\\\\`" |> test_expr
    @test "x\"\\\\\"" |> test_expr
    @test "x\"\\\\ \"" |> test_expr
    @test "a.{1}" |> test_expr
    @test "@~" |> test_expr
    @test "\$\$(x)" |> test_expr
    @test "\$\$(x)" |> test_expr
    @test CSTParser.headof(CSTParser.parse("=")) === :errortoken
    @test CSTParser.headof(CSTParser.parse("~")) === :OPERATOR
    @test "(1:\n2)" |> test_expr
    @test "a[: ]" |> test_expr
    @test ".~b" |> test_expr
    if VERSION > v"1.1-"
        @test "a .~ b" |> test_expr
    end
    @test "A[a~b]" |> test_expr
    @test "[a~b]" |> test_expr
    if VERSION >= v"1.6"
        @test "[a ~b]" |> test_expr
    end
    @test "[a ~ b]" |> test_expr
    @test "[a~ b]" |> test_expr
    @test "1 .< 2 .< 3" |> test_expr
    @test "(;)" |> test_expr
    if VERSION > v"1.5"
        @test "@M{a}-b" |> test_expr
        @test "@M{a,b}-b" |> test_expr
    end
    @test "@M[a]-b" |> test_expr
end

@testitem "interpolation error catching" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    x = CSTParser.parse("\"a \$ b\"")
    @test x.fullspan == 7
    @test CSTParser.headof(x[3]) === :errortoken
    x = CSTParser.parse("\"a \$# b\"")
    @test x.fullspan == 8
    @test CSTParser.headof(x[3]) === :errortoken
end



@testitem "string interpolation" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION >= v"1.6"
        @test test_expr(raw""""$("asd")" """)
        @test test_expr(raw""""$("asd")a" """)
        @test test_expr(raw""""a$("asd")" """)
        @test test_expr(raw""""a$("asd")a" """)
        @test test_expr(raw"""`$("asd")` """)
        @test test_expr(raw"""`$("asd")a` """)
        @test test_expr(raw"""`a$("asd")` """)
        @test test_expr(raw"""`a$("asd")a` """)
    end
end
@testitem "string whitespace handling" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION >= v"1.6"
        @test test_expr("""\"\"\"\n\\t\"\"\" """)
        @test test_expr("""\"\"\"\n\\t\n\"\"\" """)
        @test test_expr("""\"\"\"\n\\t\\n\"\"\" """)
        @test test_expr(raw"""\"\"\"\n\\t\"\"\" """)
        @test test_expr(raw"""\"\"\"\n\\t\n\"\"\" """)
        @test test_expr(raw"""\"\"\"\n\\t\\n\"\"\" """)
    end
end

@testitem "cmd interpolation" begin
    using CSTParser: remlineinfo!, valof
    include("../shared.jl")

    @test test_expr("`a \$b c`")
    @test test_expr(raw"`a \"\$b $b\" c`")
    @test test_expr("`a b c`")
    x = CSTParser.parse("`a \$b c`")
    @test x.args[1].head == :globalrefcmd
    @test x.args[3].head == :string
    @test valof(x.args[3].args[1]) == "a "
    @test valof(x.args[3].args[2]) == "b"
    @test valof(x.args[3].args[3]) == " c"
end

@testitem "multiple ; in kwargs" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("f(a; b=1; c=2)")
    @test test_expr("f(a; b=1; c=2) = 2")
    @test test_expr("f( ; b=1; c=2)")
    @test test_expr("f(a; b=1; c=2)")
    @test test_expr("f(a; b=1, c=2; d=3)")
    @test test_expr("f(a; b=1; c=2, d=3)")
    @test test_expr("f(a; b=1; c=2; d=3)")
end

@testitem "Broken things" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test_broken "\$(a) * -\$(b)" |> test_expr_broken
end

# test_fsig_decl(str) = (x->x.id).(CSTParser._get_fsig(CSTParser.parse(str)).defs)
# @testitem "func-sig variable declarations" begin
#     @test test_fsig_decl("f(x) = x") == [:x]
#     @test test_fsig_decl("""function f(x)
#         x
#     end""") == [:x]

#     @test test_fsig_decl("f{T}(x::T) = x") == [:T, :x]
#     @test test_fsig_decl("""function f{T}(x::T)
#         x
#     end""") == [:T, :x]

#     @test test_fsig_decl("f(x::T) where T = x") == [:T, :x]
#     @test test_fsig_decl("""function f(x::T) where T
#         x
#     end""") == [:T, :x]


#     @test test_fsig_decl("f(x::T{S}) where T where S = x") == [:T, :S, :x]
#     @test test_fsig_decl("""function f(x::T{S}) where T where S
#         x
#     end""") == [:T, :S, :x]
# end

@testitem "Spans" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    CSTParser.parse(raw"""
    "ABC$(T)"
    """).fullspan >= 9
    CSTParser.parse("\"_\"").fullspan == 3
    CSTParser.parse("T.mutable && print(\"Ok\")").fullspan == 24
    CSTParser.parse("(\"\$T\")").fullspan == 6
    CSTParser.parse("\"\"\"\$T is not supported\"\"\"").fullspan == 25
    CSTParser.parse("using Compat: @compat\n").fullspan == 22
    CSTParser.parse("primitive = 1").fullspan == 13
end

@testitem "Command or string with unicode" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "```αhelloworldω```" |> test_expr
    @test "\"αhelloworldω\"" |> test_expr
end

@testitem "conversion of floats with underscore" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "30.424_876_125_859_513" |> test_expr
end

@testitem "errors" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test headof(CSTParser.parse("1? b : c ").args[1]) === :errortoken
    @test headof(CSTParser.parse("1 ?b : c ").trivia[1]) === :errortoken
    @test headof(CSTParser.parse("1 ? b :c ").trivia[2]) === :errortoken
    @test headof(CSTParser.parse("1:\n2").args[1]) === :errortoken
    @test headof(CSTParser.parse("1.a").args[2]) === :errortoken
    @test headof(CSTParser.parse("f ()")) === :errortoken
    @test headof(CSTParser.parse("f{t} ()")) === :errortoken
    @test headof(CSTParser.parse(": a").trivia[1]) === :errortoken
    @test headof(CSTParser.parse("const a").args[1]) === :errortoken
end

@testitem "colons" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("(if true I elseif false J else : end for i in 1:5)")
    @test test_expr("if true; : end")
    @test test_expr("a + :")
end

@testitem "tuple params" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "1,2,3" |> test_expr
    @test "1;2,3" |> test_expr
    @test "1,2;3" |> test_expr
    @test "(1,2,3)" |> test_expr
    @test "(1;2,3)" |> test_expr
    @test "(1,2;3)" |> test_expr
    @test "f(;)" |> test_expr
end

@testitem "docs" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "\"doc\"\nT" |> test_expr
    @test "@doc \"doc\" T" |> test_expr
    @test "@doc \"doc\"\nT" |> test_expr
    @test "@doc \"doc\n\n\n\"\nT" |> test_expr
    @test "begin\n@doc \"doc\"\n\nT\nend" |> test_expr
    @test "begin\n@doc \"doc\"\nT\nend" |> test_expr
    @test "begin\n@doc \"doc\" T\nend" |> test_expr
    @test "if true\n@doc \"doc\"\n\nT\nend" |> test_expr
    @test "if true\n@doc \"doc\"\nT\nend" |> test_expr
    @test "if true\n@doc \"doc\" T\nend" |> test_expr
    @test "@doc \"I am a module\" ModuleMacroDoc" |> test_expr
    @test """
    @doc(foo)
    """ |> test_expr
    @test """
    @doc foo
    """ |> test_expr
end

@testitem "braces" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "{a}" |> test_expr
    @test "{a, b}" |> test_expr
    @test "{a, b; c}" |> test_expr
    @test "{a, b; c = 1}" |> test_expr
    @test "{a b}" |> test_expr
    @test "{a b; c}" |> test_expr
    @test "{a b; c = 1}" |> test_expr
end

@testitem "import preceding dot whitespace" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test "using . M" |> test_expr
    @test "using .. M" |> test_expr
    @test "using ... M" |> test_expr
end

@testitem "issue #116" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test """
    function foo() where {A <:B}
    body
    end""" |> test_expr

    @test """
    function foo() where {A <: B}
    body
    end""" |> test_expr
end

@testitem "issue #165" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    x = CSTParser.parse("""
    a ? b
    function f end""")
    @test length(x) == 5 # make sure we always give out an EXPR of the right length
    @test headof(x.args[3]) === :errortoken
end

@testitem "issue #182" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    x = CSTParser.parse("""
    quote
        \"\"\"
        txt
        \"\"\"
        sym
    end""")
    @test x.args[1].args[1].args[1].head === :globalrefdoc
end

@testitem "issue #198" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.3.0-"
        @test test_expr(":var\"id\"")
    end
end
@testitem "vscode issue #1632" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("\"\$( a)\"")
    @test test_expr("\"\$(#=comment=# a)\"")
end
@testitem "issue #210" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("function f(a; where = false) end")
end

@testitem "suffixed ops" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("a +₊ b *₊ c")
    @test test_expr("a *₊ b +₊ c")
end


@testitem "import .. as .. syntax" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @static if VERSION > v"1.6-"
        @test test_expr("import a as b")
        @test test_expr("import a as b, c")
        @test test_expr("import M: a as b")
        @test test_expr("import M: a as b, c")
        @test CSTParser.parse("using a as b")[2].head === :errortoken
        @test test_expr("using M: a as b")
        @test test_expr("using M: a as b, c")
        @test test_expr(raw":(import $foo as $bar)")
    end
end
@testitem "exor #201" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(raw"$return(x)")
end



@testitem "@var #236" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.3.0-"
        s = raw"""@var" " a"""
        @test test_expr(s)
        @test CSTParser.ismacroname(CSTParser.parse(s).args[1])
    end
end

@testitem "nonstandard identifier (var\"blah\") parsing" begin
using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.3.0-"
        @test """var"asd" """ |> test_expr
        @test """var"#asd" """ |> test_expr
        @test """var"#asd#" """ |> test_expr
        @test """M.var"asd" """ |> test_expr
        @test """M.var"#asd" """ |> test_expr
        @test """M.var"#asd#" """ |> test_expr
    end
end
@testitem "bad uint" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test to_codeobject(CSTParser.parse("0x.")) == Expr(:error)
end

@testitem "endswithtrivia" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    x = CSTParser.parse("\"some long title \$label1 \$label2\" \na")
    @test x[3].span < x[3].fullspan
    @test CSTParser.lastchildistrivia(x[3])
end

@testitem "bad interp with following newline" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    s = "\"\"\"\$()\n\"\"\""
    x = CSTParser.parse(s)
    @test sizeof(s) == x.fullspan
end

@testitem "minimal_reparse" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    s0 = """
    testsettravx=nothing;
        ) fx;ifxend)
            # parsing works?"""
    s1 = """
    testsettravx=nothing;
        ) ;ifxend)
            # parsing works?"""
    x0 = CSTParser.parse(s0, true)
    x1 = CSTParser.parse(s1, true)
    x2 = CSTParser.minimal_reparse(s0, s1, x0, x1)
    @test CSTParser.comp(x1, x2)
end

@testitem "primes" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("""
    f() do x
        end'
    """)
    @test CSTParser.has_error(cst"begin end'")
    @test !CSTParser.has_error(cst"[]'")
    @test !CSTParser.has_error(cst"'a''")
    @test test_expr("(a)'")
    @test test_expr("a.a'")
    if VERSION >= v"1.6"
        @test test_expr("a'ᵀ")
        @test test_expr(":(a'ᵀ)")
    end
    @test test_expr("a'")
    @test test_expr("a''")
    @test test_expr("a'''")
    # @test test_expr(":.'")
    # @test test_expr(":?'")
    # @test test_expr(":a'")
end

@testitem "end as id juxt" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("a[1end]")
    if VERSION >= v"1.4"
        @test test_expr("a[2begin:1end]")
    end
end

@testitem "last child is trivia for :string" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test !CSTParser.lastchildistrivia(cst"""("a $(A) a"  )"""[2])
end

@testitem "toplevel strings" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(""""a" in b && c""")
end

@testitem "@doc cont" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("module a\n@doc doc\"\"\"doc\"\"\"\nx\nend")
end

@testitem "char escape" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(raw"'\$'")
    @test test_expr(raw"'\a'")
    @test test_expr(raw"'\3'")
    @test test_expr(raw"'\000'")
    @test test_expr(raw"'\033'")
    @test test_expr(raw"'\177'")
    @test test_expr(raw"'\u222'")
    @test test_expr(raw"'\ufff'")
    @test test_expr(raw"'\x2'")
    @test test_expr(raw"'\x22'")
    @test test_expr(raw"'\u22'")
    @test test_expr(raw"'\u2222'")
    @test test_expr(raw"'\U2222'")
    @test test_expr(raw"'\U22222'")
    @test test_expr(raw"'\U00000001'")
    if VERSION > v"1.9-"
        @test test_expr(raw"'\xff'")
        @test test_expr(raw"'\xc0\x80'")
    end

    @test CSTParser.parse(raw"'\200'").head == :errortoken
    @test CSTParser.parse(raw"'\300'").head == :errortoken
    @test CSTParser.parse(raw"'\377'").head == :errortoken
    @test CSTParser.parse(raw"'\600'").head == :errortoken
    @test CSTParser.parse(raw"'\777'").head == :errortoken
    @test CSTParser.parse(raw"'\x222'").head == :errortoken
    @test CSTParser.parse(raw"'\u22222'").head == :errortoken
    @test CSTParser.parse(raw"'\U222222'").head == :errortoken
    @test CSTParser.parse(raw"'\asdd'").head == :errortoken
    @test CSTParser.parse(raw"'\α'").head == :errortoken
    @test CSTParser.parse(raw"'\αsdd'").head == :errortoken
    @test CSTParser.parse(raw"'\u222ää'").head == :errortoken
    @test CSTParser.parse(raw"'\x222ää'").head == :errortoken
    @test CSTParser.parse(raw"'\U222ää'").head == :errortoken
    @test CSTParser.parse(raw"'\U10000001'").head == :errortoken
    for c in rand(Char, 1000)
        c == '\\' && continue
        @test test_expr(string("'", c, "'"))
    end
end

@testitem "invalid char in string" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test CSTParser.parse(raw"\"\U222222222\"").head == :errortoken
end

@testitem "string macros" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(raw"""test"asd"asd""")
    @test test_expr(raw"""Mod.test"asd"asd""")
    if VERSION >= v"1.6"
        @test test_expr(raw"""test"asd"0""")
        @test test_expr(raw"""test"asd"0o0""")
        @test test_expr(raw"""test"asd"0x0""")
        @test test_expr(raw"""test"asd"0.0""")
    end
    # this regressed in JuliaSyntax: https://github.com/JuliaLang/JuliaSyntax.jl/issues/401
    if VERSION <= v"1.10-"
        @test test_expr(raw"""test"asd"true""")
        @test test_expr(raw"""test""true""")
    end
end

@testitem "number parsing" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("0b00000000")
    @test test_expr("0b000000000")
    @test test_expr("0b0000000000000000")
    @test test_expr("0b00000000000000000")
    @test test_expr("0b00000000000000000000000000000000")
    @test test_expr("0b000000000000000000000000000000000")
    @test test_expr("0b0000000000000000000000000000000000000000000000000000000000000000")
    @test test_expr("0b00000000000000000000000000000000000000000000000000000000000000000")
    @test test_expr("0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    if VERSION >= v"1.6"
        @test test_expr("0b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    end
    @test test_expr("0b11111111")
    @test test_expr("0b111111111")
    @test test_expr("0b1111111111111111")
    @test test_expr("0b11111111111111111")
    @test test_expr("0b11111111111111111111111111111111")
    @test test_expr("0b111111111111111111111111111111111")
    @test test_expr("0b1111111111111111111111111111111111111111111111111111111111111111")
    @test test_expr("0b11111111111111111111111111111111111111111111111111111111111111111")
    @test test_expr("0b11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
    if VERSION >= v"1.6"
        @test test_expr("0b111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
    end

    @test test_expr("0o0")
    @test test_expr("0o00")
    @test test_expr("0o0000")
    @test test_expr("0o00000")
    @test test_expr("0o000000000")
    @test test_expr("0o0000000000")
    @test test_expr("0o00000000000000000000")
    @test test_expr("0o000000000000000000000")
    @test test_expr("0o00000000000000000000000000000000000000000")
    @test test_expr("0o0000000000000000000000000000000000000000000")
    @test test_expr("0o1")
    @test test_expr("0o11")
    @test test_expr("0o1111")
    @test test_expr("0o11111")
    @test test_expr("0o111111111")
    @test test_expr("0o1111111111")
    @test test_expr("0o11111111111111111111")
    @test test_expr("0o111111111111111111111")
    @test test_expr("0o11111111111111111111111111111111111111111")
    @test test_expr("0o111111111111111111111111111111111111111111")
    @test test_expr("0o377777777777777777777777777777777777777777")
    @test test_expr("0o1111111111111111111111111111111111111111111")
    @test test_expr("0o077")
    @test test_expr("0o377")
    @test test_expr("0o400")
    @test test_expr("0o077777")
    @test test_expr("0o177777")
    @test test_expr("0o200000")
    @test test_expr("0o00000000000")
    @test test_expr("0o17777777777")
    @test test_expr("0o40000000000")
    @test test_expr("0o0000000000000000000000")
    @test test_expr("0o1000000000000000000000")
    @test test_expr("0o2000000000000000000000")
    @test test_expr("0o0000000000000000000000000000000000000000000")
    @test test_expr("0o1000000000000000000000000000000000000000000")
    @test test_expr("0o2000000000000000000000000000000000000000000")

    @test test_expr("0x00")
    @test test_expr("0x000")
    @test test_expr("0x0000")
    @test test_expr("0x00000")
    @test test_expr("0x00000000")
    @test test_expr("0x000000000")
    @test test_expr("0x0000000000000000")
    @test test_expr("0x00000000000000000")
    @test test_expr("0x00000000000000000000000000000000")
    if VERSION >= v"1.6"
        @test test_expr("0x000000000000000000000000000000000")
    end

    @test test_expr("0x11")
    @test test_expr("0x111")
    @test test_expr("0x1111")
    @test test_expr("0x11111")
    @test test_expr("0x11111111")
    @test test_expr("0x111111111")
    @test test_expr("0x1111111111111111")
    @test test_expr("0x11111111111111111")
    @test test_expr("0x11111111111111111111111111111111")
    if VERSION >= v"1.6"
        @test test_expr("0x111111111111111111111111111111111")
    end
end

@testitem "#302" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    str = """
    const _examples = PlotExample[
    PlotExample( # 1
        "Lines",
        "A simple line plot of the columns.",
        [:(
            begin
                plot(Plots.fakedata(50, 5), w = 3)
            end
        )],
    ),
    ]
    """
    @test test_expr(str)
    x, ps = CSTParser.parse(CSTParser.ParseState(str), true)
    @test ps.errored == false
end

@testitem "#304" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    str = """
    const _examples = PlotExample[
        PlotExample( # 40
            "Lens",
            "A lens lets you easily magnify a region of a plot. x and y coordinates refer to the to be magnified region and the via the `inset` keyword the subplot index and the bounding box (in relative coordinates) of the inset plot with the magnified plot can be specified. Additional attributes count for the inset plot.",
            [
                quote
                    begin
                        plot(
                            [(0, 0), (0, 0.9), (1, 0.9), (2, 1), (3, 0.9), (80, 0)],
                            legend = :outertopright,
                        )
                        plot!([(0, 0), (0, 0.9), (2, 0.9), (3, 1), (4, 0.9), (80, 0)])
                        plot!([(0, 0), (0, 0.9), (3, 0.9), (4, 1), (5, 0.9), (80, 0)])
                        plot!([(0, 0), (0, 0.9), (4, 0.9), (5, 1), (6, 0.9), (80, 0)])
                        lens!(
                            [1, 6],
                            [0.9, 1.1],
                            inset = (1, bbox(0.5, 0.0, 0.4, 0.4)),
                        )
                    end
                end,
            ],
        ),
    ]
    """
    @test test_expr(str)
    x, ps = CSTParser.parse(CSTParser.ParseState(str), true)
    @test ps.errored == false
end

@testitem "#310" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    x, ps = CSTParser.parse(CSTParser.ParseState("""import a.notvar"papa" """), true)
    @test ps.errored == true
    x, ps = CSTParser.parse(CSTParser.ParseState("""import notvar"papa" """), true)
    @test ps.errored == true
end

@testitem "#311" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(raw"import a.$b.c")
end

@testitem "kw interpolation" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr(raw""""foo $bar" """)
    @test test_expr(raw""""foo $type" """)
    @test test_expr(raw""""foo $function" """)
    @test test_expr(raw""""foo $begin" """)
    @test test_expr(raw""""foo $quote" """)
end

@testitem "broadcasted && and ||" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.7-"
        @test test_expr(raw"""a .&& b""")
        @test test_expr(raw"""a .< b .&& b .> a""")
        @test test_expr(raw"""a .|| b""")
        @test test_expr(raw"""a .< b .|| b .> a""")
    end
end


@testitem "normalized unicode ops" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    if VERSION > v"1.7-"
        @test "(·) == (·) == (⋅) == 5" |> test_expr
        @test "(−) == (-) == 6" |> test_expr
    end
end

@testitem "pair tuple" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("a => b")
    @test test_expr("a => b, c, d")
    @test test_expr("a, a => b, c, d")
end

@testitem "global" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test test_expr("global a")
    @test test_expr("global a = 1")
    @test test_expr("global a = 1, b")
    @test test_expr("global a, b")
    @test test_expr("global a, b = 2")
end

@testitem "dollar quote with prime" begin
    using CSTParser: remlineinfo!
    include("../shared.jl")

    @test raw":($a'+2')" |> test_expr
    @test raw":($(a)'+2')" |> test_expr
    @test raw":($a')" |> test_expr
    @test raw":($(a)')" |> test_expr
end
