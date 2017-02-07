module Parser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last, +
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
include("positional2.jl")
include("display.jl")

function parse_expression(ps::ParseState)
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords 
        ret = parse_kw_syntax(next(ps))
    elseif ps.nt.kind == Tokens.LPAREN
        openparen = INSTANCE(next(ps))
        ret = @default ps @closer ps paren parse_expression(ps)
        closeparen = INSTANCE(next(ps))
        if ret isa EXPR && ret.head == TUPLE
            unshift!(ret.punctuation, openparen)
            push!(ret.punctuation, closeparen)
            ret.span += openparen.span + closeparen.span
        end
    elseif ps.nt.kind == Tokens.LSQUARE
        start = ps.nt.startbyte
        ret = @default ps @closer ps square parse_expression(next(ps))
        if ret isa EXPR && ret.head==TUPLE #&& ret.loc.start==start
            ret = EXPR(VECT, ret.args, ps.nt.endbyte - start)
        else
            ret = EXPR(VECT, [ret], ps.nt.endbyte - start)
        end
        next(ps)
    elseif ps.nt.kind == Tokens.LBRACE
        error("discontinued cell1d syntax")
    elseif isinstance(ps.nt)
        ret = INSTANCE(next(ps))
    elseif isunaryop(ps.nt)
        ret = parse_unary(next(ps))
    elseif ps.nt.kind==Tokens.AT_SIGN
        ret = parse_macrocall(next(ps))
    else
        error("Expression started with $(ps)")
    end

    while !closer(ps)
        if isoperator(ps.nt)
            ret = parse_operator(ps, ret)
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                ret = @default ps @closer ps paren parse_call(ps, ret)
            else
                error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
            end
        elseif ps.nt.kind==Tokens.LBRACE
            if isempty(ps.ws.val)
                next(ps)
                start = ps.t.startbyte
                puncs = [INSTANCE(ps)]
                args = @closer ps brace parse_list(ps, puncs)
                push!(puncs, INSTANCE(next(ps)))
                ret = EXPR(CURLY, [ret, args...], ret.span + ps.t.endbyte - start, puncs)
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind==Tokens.LSQUARE
            if isempty(ps.ws.val)
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
            error("infinite loop $(ps)")
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
    
    puncs = [INSTANCE(next(ps))]
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
    @assert length(ps.ws.val)>0
    next(ps)
    op = INSTANCE(ps)
    range = parse_expression(ps)
    if range.head==CALL && range.args[1] isa INSTANCE && range.args[1].val=="in" || range.args[1].val=="∈"
        range = EXPR(INSTANCE{OPERATOR}("=", range.args[1].ws, range.args[1].span), range.args[2:3], range.span)
    end

    ret = EXPR(INSTANCE{KEYWORD}("generator", op.ws, op.span), [ret, range])
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
    ret = EXPR(MACROCALL, [INSTANCE(next(ps))], -start)
    isempty(ps.ws.val) && !closer(ps) && error("invalid macro name")
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
    if ps.formatcheck && ps.ws.val!=""
        push!(ps.hints, "remove whitespace at $(ps.nt.startbyte)")
    end
    next(ps)
    op = INSTANCE(ps)
    start = ps.t.startbyte
    if isassignment(ps.nt)
        if ret isa EXPR && ret.head!=TUPLE
            ret =  EXPR(TUPLE, [ret], ps.t.endbyte - start, [op])
        end
    else
        nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE
            push!(ret.args, nextarg)
            push!(ret.punctuation, op)
            ret.span += ps.t.endbyte-start
        else
            ret =  EXPR(TUPLE, [ret, nextarg], ret.span+ps.t.endbyte-start, [op])
        end
    end
    return ret
end


function parse(str::String, cont = false)
    ps = Parser.ParseState(str)
    ret = parse_expression(ps)
    return ret
end


ischainable(t::Token) = t.val == "+" || t.val == "*" || t.val == "~"
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13




end