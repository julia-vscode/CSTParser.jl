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


function parse_expression(ps::ParseState, closer = closer_default)
    next(ps)
    ret = nothing
    
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords 
        ret = parse_resword(ps, Val{ps.t.kind})
    elseif closer(ps)
        if ps.t.kind == Tokens.IDENTIFIER
            return IDENTIFIER(ps)
        elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
            return LITERAL(ps)
        else
            error("closer -> $(ps.t) not handled")
        end
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_expression(ps, ps->ps.nt.kind==Tokens.RPAREN)
        @assert ps.nt.kind == Tokens.RPAREN
        next(ps)
    elseif ps.t.kind == Tokens.IDENTIFIER 
        if ps.nt.kind == Tokens.LPAREN
            ret = parse_call(ps)
        elseif ps.nt.kind == Tokens.LBRACE
            ret = parse_curly(ps)
        else
            ret = IDENTIFIER(ps)
        end
    elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
            ret = LITERAL(ps)
    elseif ps.t.kind == Tokens.IDENTIFIER
        ret = IDENTIFIER(ps)
    end

    while isbinaryop(ps.nt) && !closer(ps)
        next(ps)
        op = OPERATOR(ps)
        nextarg = parse_expression(ps, closer_no_ops(precedence(op)-LtoR(op)))
        if ret isa CALL && op.val == ret.name.val && op.val in ["+", "*"]
            push!(ret.args, nextarg)
        elseif op.precedence==1
            ret = SYNTAXCALL(op, [ret, nextarg])
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
        return FUNCTION(false, IDENTIFIER(ps), BLOCK())
    end
    fcall = parse_call(ps)
    # fcall = parse_expression(ps, ps->closer_default(ps) || ps.nws!="")
    body = parse_resword(ps, Val{Tokens.BEGIN})
    return FUNCTION(false, fcall, body)
end

function parse_call(ps::ParseState)
    fname = IDENTIFIER(ps)
    @assert ps.nt.kind==Tokens.LPAREN
    args = parse_argument_list(ps)
    fcall = CALL(fname, args)

    if ps.nt.kind == Tokens.EQ
        next(ps)
        body = parse_expression(ps)
        body = body isa BLOCK ? body : BLOCK(true, [body])
        return FUNCTION(true, fcall, body)
    end

    return fcall
end

function parse_argument_list(ps::ParseState)
    @assert ps.nt.kind==Tokens.LPAREN "parse_argument_list called without ps.t=='('"
    closer = ps->ps.nt.kind==Tokens.RPAREN
    delim = ps->ps.nt.kind in [Tokens.COMMA, Tokens.RPAREN]
    
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
    return args
end

parse_resword(ps::ParseState, ::Type{Val{Tokens.RETURN}}) = RETURN(ps.ws.val, parse_expression(ps))



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
    ret = BLOCK(false, [])
    while ps.nt.kind!==Tokens.END
        push!(ret.args, parse_expression(ps))
    end
    return ret
end

# Type Declarations

function parse_resword(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    next(ps)
    decl = parse_expression
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    bits = parse_expression(ps, closer_ws_no_newline)
    decl = parse_expression(ps)
    return BITSTYPE(bits, decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}})
    name = parse_expression(ps)
    fields = parse_resword(ps, Val{Tokens.BEGIN})
    return IMMUTABLE(name, fields)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPE}})
    name = parse_expression(ps)
    fields = parse_resword(ps, Val{Tokens.BEGIN})
    return TYPE(name, fields)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    decl = parse_expression(ps, closer_ws_no_newline)
    def = parse_expression(ps)
    return TYPEALIAS(decl, def)
end




function parse_resword(ps::ParseState, ::Type{Val{Tokens.CONST}})
    decl = parse_expression(ps)
    return CONST(decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    decl = parse_expression(ps)
    return GLOBAL(decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    decl = parse_expression(ps)
    return LOCAL(decl)
end






function parse(str::String) 
    ps = Parser.ParseState(str)
    return parse_expression(ps)
end






ischainable(op::OPERATOR) = op.val == "+" || op.val == "*" || op.val == "~"
LtoR(op::OPERATOR) = op.precedence in [5,12,13]

include("utils.jl")

end