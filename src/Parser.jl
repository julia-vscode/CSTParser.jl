module Parser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last, +, isempty
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState

include("parsestate.jl")
include("utils.jl")
include("spec.jl")
include("positional.jl")
include("conversion.jl")
include("components/curly.jl")
include("components/operators.jl")
include("components/functions.jl")
include("components/generators.jl")
include("components/ifblock.jl")
include("components/loops.jl")
include("components/macros.jl")
include("components/modules.jl")
include("components/prefixkw.jl")
include("components/tryblock.jl")
include("components/types.jl")
include("display.jl")


"""
    parse_expression(ps)

Parses an expression until `closer(ps) == true`. Expects to enter the 
`ParseState` the token before the the beginning of the expression and ends 
on the last token. 

Acceptable starting tokens are: 
+ A keyword
+ An opening parentheses or brace.
+ An operator.
+ An instance (e.g. identifier, number, etc.)
+ An `@`.

"""
function parse_expression(ps::ParseState)
    next(ps)
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords 
        ret = parse_kw(ps, Val{ps.t.kind})
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_paren(ps)
    elseif ps.t.kind == Tokens.LSQUARE
        ret = parse_square(ps)
    elseif ps.t.kind == Tokens.LBRACE
        error("discontinued cell1d syntax")
    elseif ps.t.kind == Tokens.COLON
        ret = parse_quote(ps)
    elseif ps.t.kind == Tokens.TRIPLE_STRING
        ret = parse_doc(ps)
    elseif isinstance(ps.t) || isoperator(ps.t)
        ret = INSTANCE(ps)
    elseif ps.t.kind==Tokens.AT_SIGN
        ret = parse_macrocall(ps)
    else
        error("Expression started with $(ps)")
    end

    while !closer(ps)
        ret = parse_juxtaposition(ps, ret)
    end
    if ps.nt.kind==Tokens.SEMICOLON
        next(ps)
    end

    return ret
end


"""
    parse_juxtaposition(ps, ret)

"""
function parse_juxtaposition(ps::ParseState, ret)
    if isoperator(ps.nt)
        ret = parse_operator(ps, ret)
    elseif ps.nt.kind==Tokens.LPAREN
        if isempty(ps.ws)
            ret = @default ps @closer ps paren parse_call(ps, ret)
        else
            error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
        end
    elseif ps.nt.kind==Tokens.LBRACE
        if isempty(ps.ws)
            ret = parse_curly(ps, ret)
        else
            error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
        end
    elseif ps.nt.kind==Tokens.LSQUARE
        if isempty(ps.ws)
            parse_cat(ps, ret)
        else
            error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
        end
    elseif ps.nt.kind == Tokens.COMMA
        ret = parse_comma(ps, ret)
    elseif ps.nt.kind == Tokens.FOR 
        ret = parse_generator(ps, ret)
    elseif ret isa INSTANCE{IDENTIFIER,Tokens.IDENTIFIER} && ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING
        next(ps)
        arg = INSTANCE(ps)
        ret = EXPR(x_STR, [ret, arg], ret.span + arg.span)
    elseif isinstance(ps.nt)
        if isunaryop(ps.t)
            ret = parse_unary(ps, ret)
        elseif isoperator(ps.t)
            error("$ret is not a unary operator")
        else 
            error("unexpected at $ps")
        end
    else
        for s in stacktrace()
            println(s)
        end
        for f in fieldnames(ps.closer)
            if getfield(ps.closer, f)==true
                println(f, ": true")
            end
        end
        error("infinite loop at $(ps)")
    end
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret)
    start = ps.nt.startbyte
    
    puncs = INSTANCE[INSTANCE(next(ps))]
    args = @nocloser ps newline @closer ps paren parse_list(ps, puncs)
    push!(puncs, INSTANCE(next(ps)))

    ret = EXPR(CALL, [ret, args...], ret.span + ps.ws.endbyte - start + 1, puncs)
    return ret
end

"""
    parse_list(ps)

Parses a list of comma seperated expressions finishing when the parent state
of `ps.closer` is met. Expects to start at the first item and ends on the last
item so surrounding punctuation must be handled externally.
"""
function parse_list(ps::ParseState, puncs)
    args = Expression[]

    while !closer(ps)
        a = @nocloser ps newline @closer ps comma parse_expression(ps)
        push!(args, a)
        if ps.nt.kind==Tokens.COMMA
            push!(puncs, INSTANCE(next(ps)))
        end
    end

    if ps.t.kind == Tokens.COMMA
        if ps.formatcheck 
            push!(ps.hints, "extra comma unneeded at $(last(puncs).offset)")
        end
    end
    return args
end

"""
    parseblocks(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR = EXPR(BLOCK, [], 0))
    start = ps.nt.startbyte
    while ps.nt.kind!==Tokens.END
        push!(ret.args, @closer ps block parse_expression(ps))
    end
    @assert ps.nt.kind==Tokens.END
    ret.span = ps.ws.endbyte - start + 1
    return ret
end

function parse_comma(ps::ParseState, ret)
    if ps.formatcheck && !isempty(ps.ws)
        push!(ps.hints, "remove whitespace at $(ps.nt.startbyte)")
    end
    next(ps)
    op = INSTANCE(ps)
    start = ps.t.startbyte
    if isassignment(ps.nt)
        if ret isa EXPR && ret.head!=TUPLE
            ret =  EXPR(TUPLE, Expression[ret], ps.t.endbyte - start + 1, INSTANCE[op])
        end
    elseif closer(ps)
        ret = EXPR(TUPLE, Expression[ret], ret.span + op.span, INSTANCE[op])
    else
        nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE
            push!(ret.args, nextarg)
            push!(ret.punctuation, op)
            ret.span += ps.ws.endbyte-start + 1
        else
            ret =  EXPR(TUPLE, Expression[ret, nextarg], ret.span+ps.ws.endbyte - start + 1, INSTANCE[op])
        end
    end
    return ret
end


"""
    parse_paren(ps, ret)

Parses the juxtaposition of `ret` with an opening parentheses. Parses a comma 
seperated list.
"""
function parse_paren(ps::ParseState)
    start = ps.t.startbyte
    openparen = INSTANCE(ps)
    if ps.nt.kind == Tokens.RPAREN
        ret = EXPR(TUPLE, [])
    else
        ret = @default ps @closer ps paren parse_expression(ps)
    end
    closeparen = INSTANCE(next(ps))
    if ret isa EXPR && ret.head == TUPLE
        unshift!(ret.punctuation, openparen)
        push!(ret.punctuation, closeparen)
        ret.span += openparen.span + closeparen.span
    elseif ret isa EXPR && ret.head isa INSTANCE{OPERATOR{20},Tokens.DDDOT}
        ret = EXPR(TUPLE, [ret], ps.ws.endbyte - start + 1, [openparen, closeparen])
    else
        ret = EXPR(BLOCK, [ret], ps.ws.endbyte - start + 1, [openparen, closeparen])
    end
    return ret
end

function parse_square(ps::ParseState)
    start = ps.t.startbyte
    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        return EXPR(VECT, [], ps.ws.endbyte - start + 1)
    else
        ret = @default ps @closer ps square parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE
            next(ps)
            return EXPR(VECT, ret.args, ps.ws.endbyte - start + 1)
        else
            next(ps)
            return EXPR(VECT, [ret], ps.ws.endbyte - start + 1)
        end 
    end
end

function parse_quote(ps::ParseState)
    start = ps.t.startbyte
    puncs = INSTANCE[INSTANCE(ps)]
    if ps.nt.kind == Tokens.IDENTIFIER
        arg = INSTANCE(next(ps))
        return QUOTENODE(arg, arg.span, puncs)
    elseif iskw(ps.nt)
        next(ps)
        arg = INSTANCE{IDENTIFIER, Tokens.IDENTIFIER}(ps.ws.endbyte-ps.t.startbyte+1,ps.t.startbyte)
        return QUOTENODE(arg, arg.span, puncs)
    elseif isliteral(ps.nt)
        return INSTANCE(next(ps))
    elseif ps.nt.kind == Tokens.LPAREN
        next(ps)
        push!(puncs, INSTANCE(ps))
        if ps.nt.kind == Tokens.RPAREN
            next(ps)
            return EXPR(QUOTE, [EXPR(TUPLE,[], 2, [pop!(puncs), INSTANCE(ps)])], 3, puncs)
        end
        arg = @closer ps paren parse_expression(ps)
        next(ps)
        push!(puncs, INSTANCE(ps))
        return EXPR(QUOTE, [arg],  ps.ws.endbyte - start + 1, puncs)
    end
end

function parse_doc(ps::ParseState)
    start = ps.t.startbyte
    doc = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(MACROCALL, [GlobalRefDOC, doc, arg], ps.ws.endbyte - start + 1)
end

function parse_cat(ps::ParseState, ret)
    next(ps)
    start = ps.t.startbyte
    opener = INSTANCE(ps)
    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        ret = EXPR(REF, [ret], ps.t.endbyte - start + 1, [opener, INSTANCE(ps)])
    else
        arg = @default ps @closer ps square parse_expression(ps)
        @assert ps.nt.kind==Tokens.RSQUARE
        next(ps)
        ret = EXPR(REF, [ret, arg], ps.t.endbyte - start + 1, [opener, INSTANCE(ps)])
    end
    return ret
end

function parse(str::String, cont = false)
    ps = Parser.ParseState(str)
    ret = parse_expression(ps)
    # Handle semicolon as linebreak
    while ps.nt.kind == Tokens.SEMICOLON
        if ret isa EXPR && ret.head == TOPLEVEL
            next(ps)
            op = INSTANCE(ps)
            arg = parse_expression(ps)
            push!(ret.punctuation, op)
            push!(ret.args, arg)
            ret.span += op.span + arg.span
        else
            next(ps)
            op = INSTANCE(ps)
            arg = parse_expression(ps)
            ret = EXPR(TOPLEVEL, [ret, arg], ret.span + arg.span + op.span, [op])
        end
    end

    return ret
end


ischainable(t::Token) = t.kind == Tokens.PLUS || t.kind == Tokens.STAR || t.kind == Tokens.APPROX
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13

end