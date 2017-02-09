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
include("conversion.jl")
include("operators.jl")
include("keywords.jl")
include("positional.jl")
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
        ret = parse_kw_syntax(ps)
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_paren(ps)
    elseif ps.t.kind == Tokens.LSQUARE
        start = ps.t.startbyte
        ret = @default ps @closer ps square parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE
            ret = EXPR(VECT, ret.args, ps.nt.endbyte - start)
        else
            ret = EXPR(VECT, [ret], ps.nt.endbyte - start)
        end
        next(ps)
    elseif ps.t.kind == Tokens.LBRACE
        error("discontinued cell1d syntax")
    elseif isunaryop(ps.t)
        ret = parse_unary(ps)
    elseif isinstance(ps.t) || isoperator(ps.t)
        ret = INSTANCE(ps)
    elseif ps.t.kind==Tokens.AT_SIGN
        ret = parse_macrocall(ps)
    else
        error("Expression started with $(ps)")
    end

    # These are the allowed juxtapositions
    while !closer(ps)
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
                next(ps)
                start = ps.t.startbyte
                opener = INSTANCE(ps)
                arg = @default ps @closer ps square parse_expression(ps)
                @assert ps.nt.kind==Tokens.RSQUARE
                next(ps)
                ret = EXPR(REF, [ret, arg], ps.t.endbyte - start, [opener, INSTANCE(ps)])
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind == Tokens.COMMA
            ret = parse_comma(ps, ret)
        elseif ps.nt.kind == Tokens.FOR 
            ret = parse_generator(ps, ret)
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
    args = @closer ps paren parse_list(ps, puncs)
    push!(puncs, INSTANCE(next(ps)))

    ret = EXPR(CALL, [ret, args...], ret.span + ps.ws.endbyte - start, puncs)
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
        a = @closer ps comma parse_expression(ps)
        push!(args, a)
        if ps.nt.kind==Tokens.COMMA
            push!(puncs, INSTANCE(next(ps)))
        end
    end
    return args
end


"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    start = ps.nt.startbyte
    
    @assert !isempty(ps.ws)
    next(ps)
    op = INSTANCE(ps)
    range = parse_expression(ps)

    ret = EXPR(INSTANCE{KEYWORD,Tokens.KEYWORD}("generator", op.ws, op.span), [ret, range], ret.span + ps.ws.endbyte - start)
    if !(ps.nt.kind==Tokens.RPAREN || ps.nt.kind==Tokens.RSQUARE)
        error("generator/comprehension syntax not followed by ')' or ']'")
    end
    return ret
end


"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    start = ps.t.startbyte
    ret = EXPR(MACROCALL, [INSTANCE(next(ps))], -start, [AT_SIGN])
    isempty(ps.ws) && !closer(ps) && error("invalid macro name")
    while !closer(ps)
        a = @closer ps ws parse_expression(ps)
        push!(ret.args, a)
    end
    ret.span+=ps.t.endbyte
    return ret
end

"""
    parseblocks(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret = EXPR(BLOCK, [], 0))
    start = ps.nt.startbyte
    while ps.nt.kind!==Tokens.END
        push!(ret.args, @closer ps block parse_expression(ps))
    end
    @assert ps.nt.kind==Tokens.END
    ret.span = ps.ws.endbyte - start
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
            ret =  EXPR(TUPLE, [ret], ps.t.endbyte - start, [op])
        end
    elseif closer(ps)
        ret = EXPR(TUPLE, [ret], ret.span + op.span, [op])
    else
        nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE
            push!(ret.args, nextarg)
            push!(ret.punctuation, op)
            ret.span += ps.ws.endbyte-start
        else
            ret =  EXPR(TUPLE, [ret, nextarg], ret.span+ps.ws.endbyte-start, [op])
        end
    end
    return ret
end


"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    next(ps)
    start = ps.t.startbyte
    puncs = INSTANCE[INSTANCE(ps)]
    args = @closer ps brace parse_list(ps, puncs)
    push!(puncs, INSTANCE(next(ps)))
    return EXPR(CURLY, [ret, args...], ret.span + ps.ws.endbyte - start, puncs)
end

"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
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
        ret = EXPR(TUPLE, [ret], ps.ws.endbyte - start, [openparen, closeparen])
    else
        ret = EXPR(BLOCK, [ret], ps.ws.endbyte - start, [openparen, closeparen])
    end
    return ret
end


function parse(str::String, cont = false)
    ps = Parser.ParseState(str)
    ret = parse_expression(ps)
    return ret
end


ischainable(t::Token) = t.kind == Tokens.PLUS || t.kind == Tokens.STAR || t.kind == Tokens.APPROX
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13

end