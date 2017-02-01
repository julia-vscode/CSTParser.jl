module Parser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState

include("parsestate.jl")
include("spec.jl")
include("conversion.jl")
include("operators.jl")
include("keywords.jl")
include("positional.jl")
include("display.jl")

function parse_expression(ps::ParseState, closer = closer_default)
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords 
        ret = parse_kw_syntax(next(ps))
    elseif ps.nt.kind == Tokens.LPAREN
        ret = parse_expression(next(ps))
        next(ps)
    elseif isinstance(ps.nt)
        ret = INSTANCE(next(ps))
    elseif isunaryop(ps.nt)
        ret = parse_unary(next(ps))
    else
        error("Expression started with $(ps)")
    end

    while !closer(ps)
        if isoperator(ps.nt)
            ret = parse_operator(ps, ret)
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                ret = parse_call(ps, ret)
            else
                error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
            end
        elseif ps.nt.kind==Tokens.LBRACE
            if isempty(ps.ws.val)
                args = parse_list(ps)
                ret = EXPR(CURLY, [ret, args...], LOCATION(ret.loc.start, ps.t.endbyte))
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind==Tokens.LSQUARE
            if isempty(ps.ws.val)
                next(ps)
                arg = parse_expression(ps)
                @assert ps.nt.kind==Tokens.RSQUARE
                next(ps)
                ret = EXPR(REF, [ret, arg], LOCATION(ret.loc.start, ps.t.endbyte))
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind == Tokens.COMMA
            next(ps)
            if isassignment(ps.nt)
                if ret isa EXPR && ret.head!=TUPLE
                    ret =  EXPR(TUPLE, [ret], LOCATION(ret.loc.start, ps.t.endbyte))
                end
            else
                nextarg = parse_expression(ps, ps->closer_default(ps) || iscomma(ps.nt) || isassignment(ps.nt))
                if ret isa EXPR && ret.head==TUPLE
                    push!(ret.args, nextarg)
                    ret.loc.stop = nextarg.loc.stop
                else
                    ret =  EXPR(TUPLE, [ret, nextarg], LOCATION(ret.loc.start, nextarg.loc.stop))
                end
            end
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

function parse_call(ps::ParseState, ret)
    args = parse_list(ps)
    ret = EXPR(CALL, [ret, args...], LOCATION(ret.loc.start, ps.t.endbyte))
    if ps.nt.kind==Tokens.EQ
        next(ps)
        op = INSTANCE(ps)
        body = parse_expression(ps)
        if !(body isa EXPR) || body.head!= BLOCK
            body = EXPR(BLOCK, [body], LOCATION(body.loc.start, body.loc.stop))
        end
        ret = EXPR(op, [ret, body], LOCATION(ret.loc.start, body.loc.stop))
    end
    return ret
end

function parse_list(ps::ParseState)
    if ps.nt.kind == Tokens.LPAREN
        closer = ps->ps.nt.kind==Tokens.RPAREN
        delim = ps-> ps.nt.kind == Tokens.COMMA || ps.nt.kind == Tokens.RPAREN
    elseif ps.nt.kind == Tokens.LBRACE
        closer = ps->ps.nt.kind==Tokens.RBRACE
        delim = ps-> ps.nt.kind == Tokens.COMMA || ps.nt.kind == Tokens.RBRACE
    end

    args = Expression[]
    while !closer(ps)
        next(ps)
        closer(ps) && break
        a = parse_expression(ps, delim)
        push!(args, a)
        if !delim(ps)
            error()
        end
    end
    next(ps)
    return args
end

function parse_generator(ps::ParseState, ret)
    @assert length(ps.ws.val)>0
    next(ps)
    op = INSTANCE(ps)
    range = parse_expression(ps)
    if range.head==CALL && range.args[1] isa INSTANCE && range.args[1].val=="in" || range.args[1].val=="∈"
        range = EXPR(INSTANCE{OPERATOR}("=", range.args[1].ws, range.args[1].loc, range.args[1].prec), range.args[2:3], range.loc)
    end

    ret = EXPR(INSTANCE{KEYWORD}("generator", op.ws, op.loc, op.prec), [ret, range])
    if !(ps.nt.kind==Tokens.RPAREN || ps.nt.kind==Tokens.RSQUARE)
        error("generator/comprehension syntax not followed by ')' or ']'")
    end
    return ret
end


"""
    parseblocks(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret = EXPR(BLOCK, [], LOCATION(0, 0)))
    start = ps.t.startbyte
    while ps.nt.kind!==Tokens.END
        push!(ret.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END))
    end
    @assert ps.nt.kind==Tokens.END
    ret.loc = LOCATION(isempty(ret.args) ? ps.nt.startbyte : first(ret.args).loc.start, ps.nt.endbyte)
    return ret
end


function parse(str::String) 
    ps = Parser.ParseState(str)
    return parse_expression(ps)
end


ischainable(t::Token) = t.val == "+" || t.val == "*" || t.val == "~"
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13


include("utils.jl")

end