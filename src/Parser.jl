module Parser
global debug = true
global allocop = 0
using Tokenize
import Base: next
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState

include("parsestate.jl")
include("spec.jl")
include("conversion.jl")
include("precedence.jl")
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
    else
        error("Expression started with $(ps.t.val)")
    end

    while !closer(ps)
        if isoperator(ps.nt)
            next(ps)
            op = INSTANCE(ps)
            op_prec = precedence(ps.t)
            nextarg = parse_expression(ps, closer_no_ops(op_prec-LtoR(op_prec)))
            if ret isa CALL && op.val == ret.name.val && (op.val == "+" || op.val == "*")
                push!(ret.args, nextarg)
            elseif op.val == ":"
                if ret isa CALL && ret.name.val == ":" && length(ret.args)==2
                    push!(ret.args, nextarg)
                else
                    ret = CALL(0, op, [ret, nextarg], op_prec)
                end
            elseif op_prec == 6
                if ret isa COMPARISON
                    push!(ret.args, op)
                    push!(ret.args, nextarg)
                else
                    ret = COMPARISON(0, [ret, op, nextarg])
                end
            else
                ret = CALL(0, op, [ret, nextarg],op_prec)
            end
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                start = ps.t.startbyte
                args = parse_list(ps)
                ret = CALL((ps.t.endbyte-start)+ret.span, ret, args, precedence(ret))
                if ps.nt.kind==Tokens.EQ
                    next(ps)
                    body = parse_expression(ps)
                    body = body isa BLOCK ? body : BLOCK(0, true, [body])
                    ret = KEYWORD_BLOCK{3}(ps.t.endbyte-start, INSTANCE{KEYWORD}(0, "function",""), [ret, body], nothing)
                end
            else
                error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
            end
        elseif ps.nt.kind==Tokens.LBRACE
            if isempty(ps.ws.val)
                start = ps.t.startbyte
                args = parse_list(ps)
                ret = CURLY(0, ret, args)
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
        delim = ps-> ps.nt.kind == Tokens.COMMA|| ps.nt.kind == Tokens.RPAREN
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
    ret = BLOCK(0, false, [])
    while ps.nt.kind!==Tokens.END
        push!(ret.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END))
    end
    ret.span = ps.t.endbyte-start
    next(ps)
    return ret
end


function parse_kw_syntax(ps::ParseState) 
    if Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        return KEYWORD_BLOCK{0}(ps.t.endbyte-start, kw, [], nothing)
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps)
        return KEYWORD_BLOCK{1}(ps.t.endbyte-start, kw, [arg1], nothing)
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        ps.ws_delim = true
        arg1 = parse_expression(ps)
        ps.ws_delim = false
        arg2 = parse_expression(ps)
        return KEYWORD_BLOCK{2}(ps.t.endbyte-start, kw, [arg1, arg2], nothing)
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END || (!isempty(ps.ws.val) && !isoperator(ps.nt)))
        arg2 = parse_block(ps)
        return KEYWORD_BLOCK{3}(ps.t.endbyte-start, kw, [arg1, arg2], INSTANCE(ps))
    elseif ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_block(ps)
        return KEYWORD_BLOCK{3}(ps.t.endbyte-start, kw, [arg1], INSTANCE(ps))
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