function closer(ps::ParseState)
    (ps.closer.newline && ps.ws.kind == NewLineWS && ps.t.kind != Tokens.COMMA) ||
    (ps.closer.semicolon && ps.ws.kind == SemiColonWS) ||
    (isoperator(ps.nt) && precedence(ps.nt) <= ps.closer.precedence) ||
    (ps.nt.kind == Tokens.WHERE && ps.closer.precedence == 5) ||
    (ps.closer.inwhere && ps.nt.kind == Tokens.WHERE) ||
    (ps.nt.kind == Tokens.LPAREN && ps.closer.precedence > 15) ||
    (ps.nt.kind == Tokens.LBRACE && ps.closer.precedence > 15) ||
    (ps.nt.kind == Tokens.LSQUARE && ps.closer.precedence > 15) ||
    (ps.nt.kind == Tokens.STRING && isemptyws(ps.ws) && ps.closer.precedence > 15) ||
    (ps.closer.precedence > 15 && ps.t.kind == Tokens.RPAREN && ps.nt.kind == Tokens.IDENTIFIER) ||
    (ps.closer.precedence > 15 && ps.t.kind == Tokens.RSQUARE && ps.nt.kind == Tokens.IDENTIFIER) ||
    (ps.nt.kind == Tokens.COMMA && ps.closer.precedence > 0) ||
    ps.nt.kind == Tokens.ENDMARKER ||
    (ps.closer.comma && iscomma(ps.nt)) ||
    (ps.closer.tuple && (iscomma(ps.nt) || isassignment(ps.nt))) ||
    (ps.nt.kind == Tokens.FOR && ps.closer.precedence > -1) ||
    (ps.closer.paren && ps.nt.kind == Tokens.RPAREN) ||
    (ps.closer.brace && ps.nt.kind == Tokens.RBRACE) ||
    (ps.closer.square && ps.nt.kind == Tokens.RSQUARE) ||
    (ps.closer.block && ps.nt.kind == Tokens.END) ||
    (ps.closer.ifelse && ps.nt.kind == Tokens.ELSEIF || ps.nt.kind == Tokens.ELSE) ||
    (ps.closer.ifop && isoperator(ps.nt) && (precedence(ps.nt) <= 0 || ps.nt.kind == Tokens.COLON)) ||
    (ps.closer.trycatch && (ps.nt.kind == Tokens.CATCH || ps.nt.kind == Tokens.FINALLY || ps.nt.kind == Tokens.END)) ||
    (ps.closer.range && ps.nt.kind == Tokens.FOR) ||
    (ps.closer.ws && !isemptyws(ps.ws) &&
        !(ps.nt.kind == Tokens.COMMA) &&
        !(ps.t.kind == Tokens.COMMA) &&
        !(!ps.closer.inmacro && ps.nt.kind == Tokens.FOR) &&
        !(ps.nt.kind == Tokens.DO) &&
        # !((isbinaryop(ps.nt.kind) && (!isemptyws(ps.nws) || !isunaryop(ps.nt))) || (!ps.closer.wsop && isbinaryop(ps.nt.kind)))) ||
        !((isbinaryop(ps.nt) && !isemptyws(ps.nws)) ||
        (isbinaryop(ps.nt) && !isunaryop(ps.nt)) ||
        (isunaryop(ps.t) && ps.ws.kind == WS) ||
        (!ps.closer.wsop && isbinaryop(ps.nt.kind)))) ||
    (ps.nt.startbyte ≥ ps.closer.stop) ||
    ps.errored
end

"""
    @closer ps rule body

Continues parsing closing on `rule`.
"""
macro closer(ps, opt, body)
    quote
        local tmp1 = $(esc(ps)).closer.$opt
        $(esc(ps)).closer.$opt = true
        out = $(esc(body))
        $(esc(ps)).closer.$opt = tmp1
        out
    end
end

"""
    @nocloser ps rule body

Continues parsing not closing on `rule`.
"""
macro nocloser(ps, opt, body)
    quote
        local tmp1 = $(esc(ps)).closer.$opt
        $(esc(ps)).closer.$opt = false
        out = $(esc(body))
        $(esc(ps)).closer.$opt = tmp1
        out
    end
end

"""
    @precedence ps prec body

Continues parsing binary operators until it hits a more loosely binding
operator (with precdence lower than `prec`).
"""
macro precedence(ps, prec, body)
    quote
        local tmp1 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.precedence = $(esc(prec))
        out = $(esc(body))
        $(esc(ps)).closer.precedence = tmp1
        out
    end
end

"""
    @default ps body

Parses the next expression using default closure rules.
"""
macro default(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.newline
        local tmp2 = $(esc(ps)).closer.semicolon
        local tmp3 = $(esc(ps)).closer.inmacro
        local tmp4 = $(esc(ps)).closer.tuple
        local tmp5 = $(esc(ps)).closer.comma
        local tmp6 = $(esc(ps)).closer.insquare
        # local tmp7 = $(esc(ps)).closer.brace
        local tmp8 = $(esc(ps)).closer.range
        local tmp9 = $(esc(ps)).closer.block
        local tmp10 = $(esc(ps)).closer.ifelse
        local tmp11 = $(esc(ps)).closer.ifop
        # local tmp12 = $(esc(ps)).closer.trycatch
        local tmp13 = $(esc(ps)).closer.ws
        local tmp14 = $(esc(ps)).closer.wsop
        local tmp15 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.newline = true
        $(esc(ps)).closer.semicolon = true
        $(esc(ps)).closer.inmacro = false
        $(esc(ps)).closer.tuple = false
        $(esc(ps)).closer.comma = false
        $(esc(ps)).closer.insquare = false
        # $(esc(ps)).closer.brace = false
        # $(esc(ps)).closer.square = false
        $(esc(ps)).closer.range = false
        $(esc(ps)).closer.ifelse = false
        $(esc(ps)).closer.ifop = false
        # $(esc(ps)).closer.trycatch = false
        $(esc(ps)).closer.ws = false
        $(esc(ps)).closer.wsop = false
        $(esc(ps)).closer.precedence = -1

        out = $(esc(body))

        $(esc(ps)).closer.newline = tmp1
        $(esc(ps)).closer.semicolon = tmp2
        $(esc(ps)).closer.inmacro = tmp3
        $(esc(ps)).closer.tuple = tmp4
        $(esc(ps)).closer.comma = tmp5
        $(esc(ps)).closer.insquare = tmp6
        # $(esc(ps)).closer.brace = tmp7
        $(esc(ps)).closer.range = tmp8
        $(esc(ps)).closer.block = tmp9
        $(esc(ps)).closer.ifelse = tmp10
        $(esc(ps)).closer.ifop = tmp11
        # $(esc(ps)).closer.trycatch = tmp12
        $(esc(ps)).closer.ws = tmp13
        $(esc(ps)).closer.wsop = tmp14
        $(esc(ps)).closer.precedence = tmp15
        out
    end
end

"""
    @scope ps scope body

Continues parsing tracking declared variables.
"""
macro scope(ps, new_scope, body)
    quote
        local tmp1 = $(esc(ps)).current_scope
        $(esc(ps)).current_scope = $(esc(new_scope))
        out = $(esc(body))
        $(esc(ps)).current_scope = tmp1
        out
    end
end

"""
    @noscope ps body

Continues parsing not tracking declared variables.
"""
macro noscope(ps, body)
    quote
        local tmp1 = $(esc(ps)).trackscope
        $(esc(ps)).trackscope = false
        out = $(esc(body))
        $(esc(ps)).trackscope = tmp1
        out
    end
end

"""
    @catcherror ps body

Checks for `ps.errored`.
"""
macro catcherror(ps, body)
    quote
        $(esc(body))
        if $(esc(ps)).errored
            return EXPR{ERROR}(EXPR[INSTANCE($(esc(ps)))], 0, Variable[], "Unknown error")
        end
    end
end


isidentifier(t::Token) = t.kind == Tokens.IDENTIFIER

isliteral(t::Token) = Tokens.begin_literal < t.kind < Tokens.end_literal

isbool(t::Token) =  Tokens.TRUE ≤ t.kind ≤ Tokens.FALSE
iscomma(t::Token) =  t.kind == Tokens.COMMA

iskw(t::Token) = Tokens.iskeyword(t.kind)

isinstance(t::Token) = isidentifier(t) ||
                       isliteral(t) ||
                       isbool(t) ||
                       iskw(t)


ispunctuation(t::Token) = t.kind == Tokens.COMMA ||
                          t.kind == Tokens.END ||
                          Tokens.LSQUARE ≤ t.kind ≤ Tokens.RPAREN

isstring(x) = false
isstring(x::EXPR{T}) where T <: Union{StringH, LITERAL{Tokens.STRING},LITERAL{Tokens.TRIPLE_STRING}} = true

isajuxtaposition(ps::ParseState, ret) = ((ret isa EXPR{LITERAL{Tokens.INTEGER}} || ret isa EXPR{LITERAL{Tokens.FLOAT}}) && (ps.nt.kind == Tokens.IDENTIFIER || ps.nt.kind == Tokens.LPAREN || ps.nt.kind == Tokens.CMD || ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING)) || (
        (ret isa EXPR{UnarySyntaxOpCall} && ret.args[2] isa EXPR{OPERATOR{16,Tokens.PRIME,false}} && ps.nt.kind == Tokens.IDENTIFIER) ||
        ((ps.t.kind == Tokens.RPAREN || ps.t.kind == Tokens.RSQUARE) && (ps.nt.kind == Tokens.IDENTIFIER || ps.nt.kind == Tokens.CMD)) ||
        ((ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING) && (ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING))) ||
        (isstring(ret) && ps.nt.kind == Tokens.IDENTIFIER && ps.ws.kind == EmptyWS)


# Testing functions



function test_order(x, out = [])
    if x isa EXPR
        for y in x
            test_order(y, out)
        end
    else
        push!(out, x)
    end
    out
end

function test_find(str)
    x = parse(str, true)
    for i = 1:sizeof(str)
        _find(x, i)
    end
end

# When using the FancyDiagnostics package, Base.parse, is the
# same as CSTParser.parse. Manually call the flisp parser here
# to make sure we test what we want, even when people load the
# FancyDiagnostics package.
function flisp_parse(str::AbstractString, pos::Int; greedy::Bool=true, raise::Bool=true)
    # pos is one based byte offset.
    # returns (expr, end_pos). expr is () in case of parse error.
    bstr = String(str)
    ex, pos = ccall(:jl_parse_string, Any,
                    (Ptr{UInt8}, Csize_t, Int32, Int32),
                    bstr, sizeof(bstr), pos-1, greedy ? 1:0)
    if raise && isa(ex,Expr) && ex.head === :error
        throw(Base.ParseError(ex.args[1]))
    end
    if ex === ()
        raise && throw(Base.ParseError("end of input"))
        ex = Expr(:error, "end of input")
    end
    return ex, pos+1 # C is zero-based, Julia is 1-based
end

function flisp_parse(str::AbstractString; raise::Bool=true)
    ex, pos = flisp_parse(str, 1, greedy=true, raise=raise)
    if isa(ex,Expr) && ex.head === :error
        return ex
    end
    if !done(str, pos)
        raise && throw(Base.ParseError("extra token after end of expression"))
        return Expr(:error, "extra token after end of expression")
    end
    return ex
end

function flisp_parse(stream::IO; greedy::Bool = true, raise::Bool = true)
    pos = position(stream)
    ex, Δ = flisp_parse(readstring(stream), 1, greedy = greedy, raise = raise)
    seek(stream, pos + Δ - 1)
    return ex
end

using Base.Meta
norm_ast(a::Any) = begin
    if isa(a, Expr)
        for (i, arg) in enumerate(a.args)
            a.args[i] = norm_ast(arg)
        end
        if a.head === :line
            return Expr(:line, a.args[1], :none)
        end
        if a.head === :macrocall
            fa = a.args[1]
            if fa === Symbol("@int128_str")
                return Base.parse(Int128,a.args[2])
            elseif fa === Symbol("@uint128_str")
                return Base.parse(UInt128,a.args[2])
            elseif fa === Symbol("@bigint_str")
                return  Base.parse(BigInt,a.args[2])
            elseif fa == Symbol("@big_str")
                s = a.args[2]
                n = tryparse(BigInt,s)
                if !isnull(n)
                    return get(n)
                end
                n = tryparse(BigFloat,s)
                if !isnull(n)
                    return isnan(get(n)) ? :NaN : get(n)
                end
                return s
            end
        elseif length(a.args) >= 2 && isexpr(a, :call) && a.args[1] == :- && isa(a.args[2], Number)
            return -a.args[2]
        end
        return a
    elseif isa(a, QuoteNode)
        return Expr(:quote, norm_ast(a.value))
    elseif isa(a, AbstractFloat) && isnan(a)
        return :NaN
    end
    return a
end

function check_base(dir = dirname(Base.find_source_file("base.jl")), display = false)
    N = 0
    neq = 0
    err = 0
    aerr = 0
    fail = 0
    bfail = 0
    ret = []
    oldstderr = STDERR
    redirect_stderr()
    for (rp, d, files) in walkdir(dir)
        for f in files
            file = joinpath(rp, f)
            if endswith(file, ".jl")
                N += 1
                try
                    # print(N)
                    print("\r", rpad(string(N), 5), rpad(string(signif(fail / N * 100, 3)), 8), rpad(string(signif(err / N * 100, 3)), 8), rpad(string(signif(neq / N * 100, 3)), 8))
                    str = readstring(file)
                    ps = ParseState(str)
                    io = IOBuffer(str)
                    x, ps = parse(ps, true)
                    sp = span(x)
                    if length(x.args) > 0 && x.args[1] isa EXPR{LITERAL{nothing}}
                        shift!(x.args)
                    end
                    if length(x.args) > 0 && x.args[end] isa EXPR{LITERAL{nothing}}
                        pop!(x.args)
                    end
                    x0 = Expr(x)
                    x1 = Expr(:file)
                    try
                        while !eof(io)
                            push!(x1.args, flisp_parse(io))
                        end
                    catch er
                        isa(er, InterruptException) && rethrow(er)
                        if display
                            Base.showerror(STDOUT, er, catch_backtrace())
                            println()
                        end
                        bfail += 1
                        continue
                    end
                    if length(x1.args) > 0  && x1.args[end] == nothing
                        pop!(x1.args)
                    end
                    x0, x1 = norm_ast(x0), norm_ast(x1)
                    remlineinfo!(x1)
                    print("\r                             ")
                    if !isempty(sp)
                        print_with_color(:blue, file)
                        @show sp
                        println()
                        push!(ret, (file, :span))
                    end
                    if ps.errored
                        err += 1
                        print_with_color(:yellow, file)
                        println()
                        push!(ret, (file, :errored))
                    elseif !(x0 == x1)
                        cumfail = 0
                        neq += 1
                        print_with_color(:green, file)
                        println()
                        if display
                            c0, c1 = CSTParser.compare(x0, x1)
                            aerr += 1
                            print_with_color(:light_red, string("    ", c0), bold = true)
                            println()
                            print_with_color(:light_green, string("    ", c1), bold = true)
                            println()
                        end
                        push!(ret, (file, :noteq))
                    end
                catch er
                    isa(er, InterruptException) && rethrow(er)
                    if display
                        Base.showerror(STDOUT, er, catch_backtrace())
                        println()
                    end
                    fail += 1
                    print_with_color(:red, file)
                    println()
                    push!(ret, (file, :failed))
                end
            end
        end
    end
    redirect_stderr(oldstderr)
    if bfail + fail + err + neq > 0
        println("\r$N files")
        print_with_color(:red, "failed")
        println(" : $fail    $(100*fail/N)%")
        print_with_color(:yellow, "errored")
        println(" : $err     $(100*err/N)%")
        print_with_color(:green, "not eq.")
        println(" : $neq    $(100*neq/N)%", "  -  $aerr     $(100*aerr/N)%")
        print_with_color(:magenta, "base failed")
        println(" : $bfail    $(100*bfail/N)%")
    end
    ret
end

"""
    compare(x,y)

Recursively checks whether two Base.Expr are the same. Returns unequal sub-
expressions.
"""
compare(x, y) = x == y ? true : (x, y)

function compare(x::Expr, y::Expr)
    if x == y
        return true
    else
        if x.head != y.head
            return (x, y)
        end
        if length(x.args) != length(y.args)
            return (x.args, y.args)
        end
        for i = 1:length(x.args)
            t = compare(x.args[i], y.args[i])
            if t != true
                return t
            end
        end
    end
end

"""
    span(x, neq = [])

Recursively checks whether the span of an expression equals the sum of the span
of its components. Returns a vector of failing expressions.
"""
function span(x::EXPR{StringH}, neq = []) end
function span(x, neq = [])
    s = 0
    for a in x.args
        span(a, neq)
        s += a.span
    end
    if length(x.args) > 0 && s != x.span
        push!(neq, x)
    end
    neq
end

function speed_test()
    dir = dirname(Base.find_source_file("base.jl"))
    println("speed test : ", @timed(for i = 1:5
    parse(readstring(joinpath(dir, "inference.jl")), true);
    parse(readstring(joinpath(dir, "random.jl")), true);
    parse(readstring(joinpath(dir, "show.jl")), true);
    parse(readstring(joinpath(dir, "abstractarray.jl")), true);
end)[2])
end

"""
    check_reformat()

Reads and parses all files in current directory, applys formatting fixes and checks that the output AST remains the same.
"""
function check_reformat()
    fs = filter(f -> endswith(f, ".jl"), readdir())
    for (i, f) in enumerate(fs)
        f == "deprecated.jl" && continue
        str = readstring(f)
        x, ps = parse(ParseState(str), true);
        cnt = 0
        for i = 1:length(x) - 1
            y = x[i]
            sstr = str[cnt + (1:y.span)]

            y1 = parse(sstr)
            @assert Expr(y) == Expr(y1)
            cnt += y.span
        end
    end
end



is_func_call(x) = false
is_func_call(x::EXPR) = false
is_func_call(x::EXPR{Call}) = true
is_func_call(x::EXPR{UnaryOpCall}) = true
function is_func_call(x::EXPR{BinarySyntaxOpCall})
    if length(x.args) > 1 && (x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}} || x.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}})
        return is_func_call(x.args[1])
    else
        return false
    end
end


function get_last_token(x::CSTParser.EXPR)
    if isempty(x.args)
        return x
    else
        return get_last_token(last(x.args))
    end
end

function trailing_ws_length(x::CSTParser.EXPR{CSTParser.IDENTIFIER})
    x.span - sizeof(x.val)
end

function trailing_ws_length(x::CSTParser.EXPR{P}) where P <: CSTParser.PUNCTUATION
    x.span - 1
end

function trailing_ws_length(x::CSTParser.EXPR{K}) where K <: CSTParser.KEYWORD{T} where T
    x.span - sizeof(string(T))
end

function trailing_ws_length(x::CSTParser.EXPR{K}) where K <: CSTParser.LITERAL{T} where T
    x.span - sizeof(x.val)
end
