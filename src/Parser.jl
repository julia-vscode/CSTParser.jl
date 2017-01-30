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
include("positional.jl")
include("display.jl")

function parse_expression(ps::ParseState, closer = closer_default)
    start = ps.t.startbyte
    next(ps)
    
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords 
        ret = parse_kw_syntax(ps)
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_expression(ps, ps->ps.nt.kind==Tokens.RPAREN)
        next(ps)
    elseif isinstance(ps.t)
        ret = INSTANCE(ps)
    elseif isunaryop(ps.t)
        ret = parse_unary(ps)
    else
        error("Expression started with $(ps.t.val)")
    end

    while !closer(ps)
        if isoperator(ps.nt)
            ret = parse_operator(ps, ret)
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                start = ps.t.startbyte
                args, o, c = parse_list(ps)
                ret = CALL(start, ps.t.endbyte, o, c, ret, args)
                if ps.nt.kind==Tokens.EQ
                    next(ps)
                    body = parse_expression(ps)
                    body = body isa BLOCK ? body : BLOCK(0, 0, true, [body])
                    ret = KEYWORD_BLOCK{3}(start, ps.t.endbyte, INSTANCE{KEYWORD}(ret.start, body.stop, "function",""), [ret, body], nothing)
                end
            else
                error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
            end
        elseif ps.nt.kind==Tokens.LBRACE
            if isempty(ps.ws.val)
                start = ps.t.startbyte
                args, o, c = parse_list(ps)
                ret = CURLY(start, ps.t.endbyte, o, c, ret, args)
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
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
    O = INSTANCE{DELIMINATOR}(ps.nt.startbyte, ps.nt.endbyte, ps.nt.val, ps.nws.val)

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
    C = INSTANCE{DELIMINATOR}(ps.t.startbyte, ps.t.endbyte, ps.t.val, ps.ws.val)
    return args, O, C
end

function parse_block(ps::ParseState)
    ret = BLOCK(ps.t.startbyte, 0, false, [])
    while ps.nt.kind!==Tokens.END
        push!(ret.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END))
    end
    next(ps)
    ret.stop = ps.t.endbyte
    return ret
end


function parse_kw_syntax(ps::ParseState) 
    if Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        kw = INSTANCE(ps)
        return KEYWORD_BLOCK{0}(ps.t.startbyte, ps.t.endbyte, kw, [], nothing)
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps)
        return KEYWORD_BLOCK{1}(start, ps.t.endbyte, kw, [arg1], nothing)
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        ps.ws_delim = true
        arg1 = parse_expression(ps)
        ps.ws_delim = false
        arg2 = parse_expression(ps)
        return KEYWORD_BLOCK{2}(start, ps.t.endbyte, kw, [arg1, arg2], nothing)
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END || (!isempty(ps.ws.val) && !isoperator(ps.nt)))
        arg2 = parse_block(ps)
        return KEYWORD_BLOCK{3}(start, ps.t.endbyte, kw, [arg1, arg2], INSTANCE(ps))
    elseif ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_block(ps)
        return KEYWORD_BLOCK{3}(start, ps.t.endbyte, kw, [arg1], INSTANCE(ps))
    else
        error()
    end
end


function parse(str::String) 
    ps = Parser.ParseState(str)
    return parse_expression(ps)
end


ischainable(t::Token) = t.val == "+" || t.val == "*" || t.val == "~"
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13


include("utils.jl")

end