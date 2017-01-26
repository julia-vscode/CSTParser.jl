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
include("precedence.jl")
include("positional.jl")

function parse_expression(ps::ParseState, closer = closer_default)
    next(ps)
    ret = nothing
    
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords 
        if Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_2arg_kw
            ret = parse_kw_syntax(ps, ps.t.kind)
        elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw 
            ret = parse_kw_syntax(ps, ps.t.kind)
        else
            ret = parse_resword(ps, Val{ps.t.kind})
        end
    elseif closer(ps)
        if ps.t.kind == Tokens.IDENTIFIER
            return INSTANCE(ps)
        elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
            return INSTANCE(ps)
        else
            println(ps.t)
            error("closer -> $(ps.t) not handled")
        end
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_expression(ps, ps->ps.nt.kind==Tokens.RPAREN)
        @assert ps.nt.kind == Tokens.RPAREN
        next(ps)
    elseif ps.t.kind == Tokens.IDENTIFIER 
        if ps.nt.kind == Tokens.LPAREN
            if ps.ws.val!=""
                throw(ParseError("space before \"(\" not allowed in \"f (\""))
            end
            ret = parse_call(ps)
        elseif ps.nt.kind == Tokens.LBRACE
            ret = parse_curly(ps)
        else
            ret = INSTANCE(ps)
        end
    elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
        ret = INSTANCE(ps)
    else
        error("Expression started with $(ps.t.val)")
    end

    while !closer(ps)
        next(ps)
        op = OPERATOR(ps)
        nextarg = parse_expression(ps, closer_no_ops(precedence(op)-LtoR(op)))
        if ret isa CALL && op.val == ret.name.val && op.val in ["+", "*"]
            push!(ret.args, nextarg)
        elseif op.precedence==1
            ret = SYNTAXCALL(op, [ret, nextarg])
        elseif op.precedence==6
            if ret isa COMPARISON
                push!(ret.args, op)
                push!(ret.args, nextarg)
            else
                ret = COMPARISON([ret, op, nextarg])
            end
        else
            ret = CALL(op, [ret, nextarg])
        end
    end

    return ret
end




# Functions

function parse_resword(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    @assert ps.t.kind == Tokens.FUNCTION
    next(ps)
    if ps.nt.kind==Tokens.END
        @assert isidentifier(ps.t)
        fname = INSTANCE(ps)
        next(ps)
        return FUNCTION(false, fname, BLOCK())
    end
    fcall = parse_call(ps)
    # fcall = parse_expression(ps, ps->closer_default(ps) || ps.nws!="")
    body = parse_resword(ps, Val{Tokens.BEGIN})
    return FUNCTION(false, fcall, body)
end

function parse_call(ps::ParseState)
    fname = INSTANCE(ps)
    @assert ps.nt.kind==Tokens.LPAREN
    args = parse_argument_list(ps)
    fcall = CALL(fname, args)

    if ps.nt.kind == Tokens.EQ
        next(ps)
        body = parse_expression(ps)
        body = body isa BLOCK ? body : BLOCK(0, true, [body])
        return FUNCTION(true, fcall, body)
    end

    return fcall
end

function parse_argument_list(ps::ParseState)
    @assert ps.nt.kind==Tokens.LPAREN "parse_argument_list called without ps.t=='('"
    closer = ps->ps.nt.kind==Tokens.RPAREN
    delim = ps->ps.nt.kind in [Tokens.COMMA, Tokens.RPAREN]
    
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



function parse_curly(ps::ParseState)
    name = INSTANCE(ps)
    @assert ps.nt.kind==Tokens.LBRACE "parse_argument_list called without ps.t=='{'"
    
    closer = ps->ps.nt.kind==Tokens.RBRACE
    delim = ps->ps.nt.kind in [Tokens.COMMA, Tokens.RBRACE]
    
    args = Any[]
    while !closer(ps)
        next(ps)
        a = parse_expression(ps, delim)
        push!(args, a)
        if !delim(ps)
            error()
        end
    end
    next(ps)
    return CURLY(name, args)
end


function parse_resword(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    start = ps.t.startbyte
    args = []
    while ps.nt.kind!==Tokens.END
        push!(args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END))
    end
    ret = BLOCK(ps.t.endbyte-start, false, args)
    next(ps)
    return ret
end





# These are all identical and can be replaced by one type.

function parse_kw_syntax(ps::ParseState, tk::Tokens.Kind) 
    if Tokens.begin_0arg_kw < tk < Tokens.end_0arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        return KEYWORD_BLOCK{0}(ps.t.endbyte-start, kw, [], nothing)
    elseif Tokens.begin_1arg_kw < tk < Tokens.end_1arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps)
        return KEYWORD_BLOCK{1}(ps.t.endbyte-start, kw, [arg1], nothing)
    elseif Tokens.begin_2arg_kw < tk < Tokens.end_2arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        ps.ws_delim = true
        arg1 = parse_expression(ps)
        ps.ws_delim = false
        arg2 = parse_expression(ps)
        return KEYWORD_BLOCK{2}(ps.t.endbyte-start, kw, [arg1, arg2], nothing)
    elseif Tokens.begin_3arg_kw < tk < Tokens.end_3arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END)
        arg2 = parse_resword(ps, Val{Tokens.BEGIN})
        return KEYWORD_BLOCK{3}(ps.t.endbyte-start, kw, [arg1, arg2], INSTANCE(ps))
    else
        error()
    end
end


function parse(str::String) 
    ps = Parser.ParseState(str)
    return parse_expression(ps)
end


ischainable(op::OPERATOR) = op.val == "+" || op.val == "*" || op.val == "~"
LtoR(op::OPERATOR) = op.precedence in [1,2,3,4,5,13]

include("utils.jl")

end