function closer(ps::ParseState)
    (ps.closer.newline && kindof(ps.ws) == NewLineWS && kindof(ps.t) != Tokens.COMMA) ||
    (ps.closer.semicolon && kindof(ps.ws) == SemiColonWS) ||
    (isoperator(ps.nt) && precedence(ps.nt) <= ps.closer.precedence) ||
    (kindof(ps.nt) == Tokens.WHERE && ps.closer.precedence == LazyAndOp) ||
    (ps.closer.inwhere && kindof(ps.nt) == Tokens.WHERE) ||
    (ps.closer.inwhere && ps.closer.ws && kindof(ps.t) == Tokens.RPAREN && isoperator(ps.nt) && precedence(ps.nt) < DeclarationOp) ||
    (ps.closer.precedence > WhereOp && (
        (kindof(ps.nt) == Tokens.LPAREN && !(ps.t.kind === Tokens.EX_OR)) ||
        kindof(ps.nt) == Tokens.LBRACE ||
        kindof(ps.nt) == Tokens.LSQUARE ||
        (kindof(ps.nt) == Tokens.STRING && isemptyws(ps.ws)) ||
        ((kindof(ps.nt) == Tokens.RPAREN || kindof(ps.nt) == Tokens.RSQUARE) && isidentifier(ps.nt))  
    )) ||
    (kindof(ps.nt) == Tokens.COMMA && ps.closer.precedence > 0) ||
    kindof(ps.nt) == Tokens.ENDMARKER ||
    (ps.closer.comma && iscomma(ps.nt)) ||
    (ps.closer.tuple && (iscomma(ps.nt) || isassignment(ps.nt))) ||
    (kindof(ps.nt) == Tokens.FOR && ps.closer.precedence > -1) ||
    (ps.closer.block && kindof(ps.nt) == Tokens.END) ||
    (ps.closer.paren && kindof(ps.nt) == Tokens.RPAREN) ||
    (ps.closer.brace && kindof(ps.nt) == Tokens.RBRACE) ||
    (ps.closer.square && kindof(ps.nt) == Tokens.RSQUARE) ||
    kindof(ps.nt) == Tokens.ELSEIF || 
    kindof(ps.nt) == Tokens.ELSE ||
    kindof(ps.nt) == Tokens.CATCH || 
    kindof(ps.nt) == Tokens.FINALLY || 
    (ps.closer.ifop && isoperator(ps.nt) && (precedence(ps.nt) <= 0 || kindof(ps.nt) == Tokens.COLON)) ||
    (ps.closer.range && (kindof(ps.nt) == Tokens.FOR || iscomma(ps.nt) || kindof(ps.nt) == Tokens.IF)) ||
    (ps.closer.ws && !isemptyws(ps.ws) &&
        !(kindof(ps.nt) == Tokens.COMMA) &&
        !(kindof(ps.t) == Tokens.COMMA) &&
        !(!ps.closer.inmacro && kindof(ps.nt) == Tokens.FOR) &&
        !(kindof(ps.nt) == Tokens.DO) &&
        !(
            (isbinaryop(ps.nt) && !(isemptyws(ps.nws) && isunaryop(ps.nt) && ps.closer.wsop)) || 
            (isunaryop(ps.t) && kindof(ps.ws) == WS)
        )) ||
    (ps.closer.unary && (kindof(ps.t) in (Tokens.INTEGER, Tokens.FLOAT, Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE) && kindof(ps.nt) == Tokens.IDENTIFIER))
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

macro closeparen(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.paren
        $(esc(ps)).closer.paren = true
        push!($(esc(ps)).closer.cc, :paren)
        out = $(esc(body))
        pop!($(esc(ps)).closer.cc)
        $(esc(ps)).closer.paren = tmp1
        out
    end
end

macro closesquare(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.square
        $(esc(ps)).closer.square = true
        push!($(esc(ps)).closer.cc, :square)
        out = $(esc(body))
        pop!($(esc(ps)).closer.cc)
        $(esc(ps)).closer.square = tmp1
        out
    end
end
macro closebrace(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.brace
        $(esc(ps)).closer.brace = true
        push!($(esc(ps)).closer.cc, :brace)
        out = $(esc(body))
        pop!($(esc(ps)).closer.cc)
        $(esc(ps)).closer.brace = tmp1
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


# Closer_TMP and ancillary functions help reduce code generation
struct Closer_TMP
    newline::Bool
    semicolon::Bool
    inmacro::Bool
    tuple::Bool
    comma::Bool
    insquare::Bool
    range::Bool
    ifop::Bool
    ws::Bool
    wsop::Bool
    unary::Bool
    precedence::Int
end

@noinline function create_tmp(c::Closer)
    Closer_TMP(c.newline,
        c.semicolon,
        c.inmacro,
        c.tuple,
        c.comma,
        c.insquare,
        c.range,
        c.ifop,
        c.ws,
        c.wsop,
        c.unary,
        c.precedence)
end

@noinline function update_from_tmp!(c::Closer, tmp::Closer_TMP)
    c.newline = tmp.newline
    c.semicolon = tmp.semicolon
    c.inmacro = tmp.inmacro
    c.tuple = tmp.tuple
    c.comma = tmp.comma
    c.insquare = tmp.insquare
    c.range = tmp.range
    c.ifop = tmp.ifop
    c.ws = tmp.ws
    c.wsop = tmp.wsop
    c.unary = tmp.unary
    c.precedence = tmp.precedence
end


@noinline function update_to_default!(c::Closer)
    c.newline = true
    c.semicolon = true
    c.inmacro = false
    c.tuple = false
    c.comma = false
    c.insquare = false
    c.range = false
    c.ifop = false
    c.ws = false
    c.wsop = false
    c.unary = false
    c.precedence = -1
end


"""
    @default ps body

Parses the next expression using default closure rules.
"""
macro default(ps, body)
    quote
        TMP = create_tmp($(esc(ps)).closer)
        update_to_default!($(esc(ps)).closer)
        out = $(esc(body))
        update_from_tmp!($(esc(ps)).closer, TMP)
        out
    end
end


isidentifier(t::AbstractToken) = kindof(t) == Tokens.IDENTIFIER
isidentifier(x::EXPR) = typof(x) === IDENTIFIER

isliteral(t::AbstractToken) = Tokens.begin_literal < kindof(t) < Tokens.end_literal
isliteral(x::EXPR) = typof(x) === LITERAL

isbool(t::AbstractToken) =  Tokens.TRUE ≤ kindof(t) ≤ Tokens.FALSE
iscomma(t::AbstractToken) =  kindof(t) == Tokens.COMMA

iskw(t::AbstractToken) = Tokens.iskeyword(kindof(t))
iskw(x::EXPR) = typof(x) === KEYWORD

isinstance(t::AbstractToken) = isidentifier(t) ||
                       isliteral(t) ||
                       isbool(t) ||
                       iskw(t)


ispunctuation(t::AbstractToken) = kindof(t) == Tokens.COMMA ||
                            kindof(t) == Tokens.END ||
                            Tokens.LSQUARE ≤ kindof(t) ≤ Tokens.RPAREN || 
                            kindof(t) == Tokens.AT_SIGN
ispunctuation(x::EXPR) = typof(x) === PUNCTUATION

isstring(x) = typof(x) === StringH || (isliteral(x) && (kindof(x) == Tokens.STRING || kindof(x) == Tokens.TRIPLE_STRING))
is_integer(x) = isliteral(x) && kindof(x) == Tokens.INTEGER
is_float(x) = isliteral(x) && kindof(x) == Tokens.FLOAT
is_number(x) = isliteral(x) && (kindof(x) == Tokens.INTEGER || kindof(x) == Tokens.FLOAT)
is_nothing(x) = isliteral(x) && kindof(x) == Tokens.NOTHING

isajuxtaposition(ps::ParseState, ret::EXPR) = ((is_number(ret) && (kindof(ps.nt) == Tokens.IDENTIFIER || kindof(ps.nt) == Tokens.LPAREN || kindof(ps.nt) == Tokens.CMD || kindof(ps.nt) == Tokens.STRING || kindof(ps.nt) == Tokens.TRIPLE_STRING)) || 
        ((typof(ret) === UnaryOpCall && is_prime(ret.args[2]) && kindof(ps.nt) == Tokens.IDENTIFIER) ||
        ((kindof(ps.t) == Tokens.RPAREN || kindof(ps.t) == Tokens.RSQUARE) && (kindof(ps.nt) == Tokens.IDENTIFIER || kindof(ps.nt) == Tokens.CMD)) ||
        ((kindof(ps.t) == Tokens.STRING || kindof(ps.t) == Tokens.TRIPLE_STRING) && (kindof(ps.nt) == Tokens.STRING || kindof(ps.nt) == Tokens.TRIPLE_STRING)))) || ((kindof(ps.t) in (Tokens.INTEGER, Tokens.FLOAT) || kindof(ps.t) in (Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE)) && kindof(ps.nt) == Tokens.IDENTIFIER)



# When using the FancyDiagnostics package, Base.parse, is the
# same as CSTParser.parse. Manually call the flisp parser here
# to make sure we test what we want, even when people load the
# FancyDiagnostics package.
function flisp_parse(str::AbstractString, pos::Int; greedy::Bool = true, raise::Bool = true)
    # pos is one based byte offset.
    # returns (expr, end_pos). expr is () in case of parse error.
    bstr = String(str)
    ex, pos = ccall(:jl_parse_string, Any,
                    (Ptr{UInt8}, Csize_t, Int32, Int32),
                    bstr, sizeof(bstr), pos - 1, greedy ? 1 : 0)
    if raise && isa(ex, Expr) && ex.head === :error
        throw(Meta.ParseError(ex.args[1]))
    end
    if ex === ()
        raise && throw(Meta.ParseError("end of input"))
        ex = Expr(:error, "end of input")
    end
    return ex, pos + 1 # C is zero-based, Julia is 1-based
end

function flisp_parse(str::AbstractString; raise::Bool = true)
    ex, pos = flisp_parse(str, 1, greedy = true, raise = raise)
    if isa(ex, Expr) && ex.head === :error
        return ex
    end
    if !(pos > ncodeunits(str))
        raise && throw(Meta.ParseError("extra token after end of expression"))
        return Expr(:error, "extra token after end of expression")
    end
    return ex
end

function flisp_parse(stream::IO; greedy::Bool = true, raise::Bool = true)
    pos = position(stream)
    ex, Δ = flisp_parse(read(stream, String), 1, greedy = greedy, raise = raise)
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
                return Base.parse(Int128, a.args[3])
            elseif fa === Symbol("@uint128_str")
                return Base.parse(UInt128, a.args[3])
            elseif fa === Symbol("@bigint_str")
                return  Base.parse(BigInt, a.args[3])
            elseif fa == Symbol("@big_str")
                s = a.args[3]
                n = tryparse(BigInt, s)
                if !(n == nothing)
                    return (n)
                end
                n = tryparse(BigFloat, s)
                if !(n == nothing)
                    return isnan((n)) ? :NaN : (n)
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

function flisp_parsefile(str, display = true)
    io = IOBuffer(str)
    failed = false
    x1 = Expr(:file)
    try
        while !eof(io)
            push!(x1.args, flisp_parse(io))
        end
    catch er
        isa(er, InterruptException) && rethrow(er)
        if display
            Base.showerror(stdout, er, catch_backtrace())
            println()
        end
        return x1, true
    end
    if length(x1.args) > 0  && x1.args[end] == nothing
        pop!(x1.args)
    end
    x1 = norm_ast(x1)
    remlineinfo!(x1)
    return x1, false
end

function cst_parsefile(str)
    x, ps = CSTParser.parse(ParseState(str), true)
    sp = check_span(x)
    # remove leading/trailing nothings
    if length(x.args) > 0 && is_nothing(x.args[1])
        popfirst!(x.args)
    end
    if length(x.args) > 0 && is_nothing(x.args[end])
        pop!(x.args)
    end
    x0 = norm_ast(Expr(x))
    x0, ps.errored, sp
end

function check_file(file, ret, neq)
    str = read(file, String)
    x0, cstfailed, sp = cst_parsefile(str)
    x1, flispfailed = flisp_parsefile(str)
    
    print("\r                             ")
    if !isempty(sp)
        printstyled(file, color = :blue)
        @show sp
        println()
        push!(ret, (file, :span))
    end
    if cstfailed
        printstyled(file, color = :yellow)
        println()
        push!(ret, (file, :errored))
    elseif !(x0 == x1)
        cumfail = 0
        printstyled(file, color = :green)
        println()
        c0, c1 = CSTParser.compare(x0, x1)
        printstyled(string("    ", c0), bold = true, color = :ligth_red)
        println()
        printstyled(string("    ", c1), bold = true, color = :light_green)
        println()
        push!(ret, (file, :noteq))
    end    
end

function check_base(dir = dirname(Base.find_source_file("essentials.jl")), display = false)
    N = 0
    neq = 0
    err = 0
    aerr = 0
    fail = 0
    bfail = 0
    ret = []
    oldstderr = stderr
    redirect_stderr()
    for (rp, d, files) in walkdir(dir)
        for f in files
            file = joinpath(rp, f)
            if endswith(file, ".jl")
                N += 1
                try
                    print("\r", rpad(string(N), 5), rpad(string(round(fail / N * 100, sigdigits = 3)), 8), rpad(string(round(err / N * 100, sigdigits = 3)), 8), rpad(string(round(neq / N * 100, sigdigits = 3)), 8))
                    
                    check_file(file, ret, neq)
                catch er
                    isa(er, InterruptException) && rethrow(er)
                    if display
                        Base.showerror(stdout, er, catch_backtrace())
                        println()
                    end
                    fail += 1
                    printstyled(file, color = :red)
                    println()
                    push!(ret, (file, :failed))
                end
            end
        end
    end
    redirect_stderr(oldstderr)
    if bfail + fail + err + neq > 0
        println("\r$N files")
        printstyled("failed", color = :red)
        println(" : $fail    $(100 * fail / N)%")
        printstyled("errored", color = :yellow)
        println(" : $err     $(100 * err / N)%")
        printstyled("not eq.", color = :green)
        println(" : $neq    $(100 * neq / N)%", "  -  $aerr     $(100 * aerr / N)%")
        printstyled("base failed", color = :magenta)
        println(" : $bfail    $(100 * bfail / N)%")
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
check_span(x, neq = [])

Recursively checks whether the span of an expression equals the sum of the span
of its components. Returns a vector of failing expressions.
"""
function check_span(x::EXPR, neq = [])
    (ispunctuation(x) || isidentifier(x) || iskw(x) || isoperator(x) || isliteral(x) || typof(x) == StringH) && return neq
    
    s = 0
    for a in x.args
        check_span(a, neq)
        s += a.fullspan
    end
    if length(x.args) > 0 && s != x.fullspan
        push!(neq, x)
    end
    neq
end

function speed_test()
    dir = dirname(Base.find_source_file("essentials.jl"))
    println("speed test : ", @timed(for i = 1:5
        parse(read(joinpath(dir, "essentials.jl"), String), true);
        parse(read(joinpath(dir, "abstractarray.jl"), String), true);
    end)[2])
end

"""
    check_reformat()

Reads and parses all files in current directory, applys formatting fixes and checks that the output AST remains the same.
"""
function check_reformat()
    fs = filter(f->endswith(f, ".jl"), readdir())
    for (i, f) in enumerate(fs)
        f == "deprecated.jl" && continue
        str = read(f, String)
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

function trailing_ws_length(x)
    x.fullspan - x.span
end

Base.iterate(x::EXPR) = length(x) == 0 ? nothing : (x.args[1], 1)
Base.iterate(x::EXPR, s) = s < length(x) ? (x.args[s + 1], s + 1) : nothing
Base.length(x::EXPR) = x.args isa Nothing ? 0 : length(x.args)


@inline val(token::RawToken, ps::ParseState) = String(ps.l.io.data[token.startbyte + 1:token.endbyte + 1])

function str_value(x)
    if isidentifier(x) || typof(x) === LITERAL
        return valof(x)
    elseif typof(x) === OPERATOR || typof(x) === MacroName
        return string(Expr(x))
    else
        return ""
    end
end

_unescape_string(s::AbstractString) = sprint(_unescape_string, s, sizehint = lastindex(s))
function _unescape_string(io, s::AbstractString)
    a = Iterators.Stateful(s)
    for c in a
        if !isempty(a) && c == '\\'
            c = popfirst!(a)
            if c == 'x' || c == 'u' || c == 'U'
                n = k = 0
                m = c == 'x' ? 2 :
                    c == 'u' ? 4 : 8
                while (k += 1) <= m && !isempty(a)
                    nc = Base.peek(a)
                    n = '0' <= nc <= '9' ? n << 4 + nc - '0' :
                        'a' <= nc <= 'f' ? n << 4 + nc - 'a' + 10 :
                        'A' <= nc <= 'F' ? n << 4 + nc - 'A' + 10 : break
                    popfirst!(a)
                end
                if k == 1
                    # throw(ArgumentError("invalid $(m == 2 ? "hex (\\x)" :
                    #                         "unicode (\\u)") escape sequence used in $(repr(s))"))
                    # push error to ParseState?
                    n = 0
                end
                if m == 2 # \x escape sequence
                    write(io, UInt8(n))
                else
                    print(io, Char(n))
                end
            elseif '0' <= c <= '7'
                k = 1
                n = c - '0'
                while (k += 1) <= 3 && !isempty(a)
                    c  = Base.peek(a)
                    n = ('0' <= c <= '7') ? n << 3 + c - '0' : break
                    popfirst!(a)
                end
                if n > 255
                    # throw(ArgumentError("octal escape sequence out of range"))
                    # push error to ParseState?
                    n = 255
                end
                write(io, UInt8(n))
            else
                print(io, c == 'a' ? '\a' :
                          c == 'b' ? '\b' :
                          c == 't' ? '\t' :
                          c == 'n' ? '\n' :
                          c == 'v' ? '\v' :
                          c == 'f' ? '\f' :
                          c == 'r' ? '\r' :
                          c == 'e' ? '\e' : c)
            end
        else
            print(io, c)
        end
    end
end


function match_closer(ps::ParseState)
    length(ps.closer.cc) == 0 && return false
    kind = kindof(ps.nt)
    lc = last(ps.closer.cc)
    return (kind === Tokens.RPAREN && lc == :paren) ||
           (kind === Tokens.RSQUARE && lc == :square) ||
           (kind === Tokens.RBRACE && lc == :braces) ||
           (kind === Tokens.END && (lc == :begin || lc == :if)) 
end
