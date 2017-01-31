module Parser
global debug = true

using Tokenize
import Base: next
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
        ret = parse_expression(next(ps), ps->ps.nt.kind==Tokens.RPAREN)
        # args = parse_list(ps)
        # ret = length(args)==1 ? args[1] : EXPR(TUPLE, args, LOCATION(first(args).loc.start, last(args).loc.stop))
        next(ps)
    elseif isinstance(ps.nt)
        ret = INSTANCE(next(ps))
    elseif isunaryop(ps.nt)
        ret = parse_unary(next(ps))
    else
        error("Expression started with $(ps.nt.val)")
    end

    while !closer(ps)
        if isoperator(ps.nt)
            ret = parse_operator(ps, ret)
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                start = ps.t.startbyte
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
                arg = parse_expression(ps, ps-> ps.nt.kind==Tokens.RSQUARE)
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
        end
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

function parse_block(ps::ParseState)
    start = ps.t.startbyte
    ret = EXPR(BLOCK, [], LOCATION(0, 0))
    while ps.nt.kind!==Tokens.END
        push!(ret.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END))
    end
    next(ps)
    ret.loc = LOCATION(isempty(ret.args) ? ps.t.startbyte : first(ret.args).loc.start, ps.t.endbyte)
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