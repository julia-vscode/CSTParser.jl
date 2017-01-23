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

function parse_expression(ps::ParseState, closer = closer_default)
    next(ps)
    ret = nothing
    
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords 
        ret = parse_resword(ps, Val{ps.t.kind})
    elseif closer(ps)
        if ps.t.kind == Tokens.IDENTIFIER
            return Identifier(ps)
        elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
            return Literal(ps)
        else
            error("closer -> $(ps.t) not handled")
        end
    elseif ps.t.kind == Tokens.LPAREN
        ret = parse_expression(ps, ps->ps.nt.kind==Tokens.RPAREN)
        @assert ps.nt.kind == Tokens.RPAREN
        next(ps)
    elseif ps.t.kind == Tokens.IDENTIFIER &&
                        ps.nt.kind == Tokens.LPAREN
        ret = parse_function(ps)
    elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
            ret = Literal(ps)
    elseif ps.t.kind == Tokens.IDENTIFIER
        ret = Identifier(ps)
    end

    while isbinaryop(ps.nt) && !closer(ps)
        next(ps)
        op = Operator(ps)
        nextarg = parse_expression(ps, closer_no_ops(precedence(op)-LtoR(op)))
        if ret isa FunctionCall && op.val == ret.name.val && op.val in ["+", "*"]
            push!(ret.args, nextarg)
        else
            ret = FunctionCall(op,[ret, nextarg])
        end
    end

    return ret
end


function parse_function(ps::ParseState, def=false)
    fname = Identifier(ps)
    @assert next(ps).t.kind==Tokens.LPAREN
    args = parse_argument_list(ps)
    fcall = FunctionCall(fname, args)
    if def
        next(ps)
        parse_block(ps)
    elseif ps.nt.kind == Tokens.EQ
        def = true
        next(ps)
        expr = parse_expression(ps)
        ret = FunctionDef(true, fcall, [expr])
    else
        ret = fcall
    end
    return ret
end


function parse_argument_list(ps::ParseState)
    @assert ps.t.kind==Tokens.LPAREN "parse_argument_list called without ps.t=='('"
    closer = ps->ps.nt.kind==Tokens.RPAREN
    delim = ps->ps.nt.kind in [Tokens.COMMA, Tokens.RPAREN]
    
    args = Any[]
    while true
        if closer(ps)
            break
        end
        a = parse_expression(ps, delim)
        push!(args, a)
        if !delim(ps)
            error()
        elseif closer(ps)
            next(ps)
            break
        end
    end
    return args
end




function parse_resword(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    
end


# Type Declarations

function parse_resword(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    next(ps)
    decl = parse_expression
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    bits = parse_expression(ps, closer_ws_no_newline)
    decl = parse_expression(ps)
    return bitstypeDef(bits, decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}})
    
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPE}})
    
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    decl = parse_expression(ps, closer_ws_no_newline)
    def = parse_expression(ps)
    return typealiasDef(decl, def)
end




function parse(str::String) 
    ps = Parser.ParseState(str)
    return parse_expression(ps)
end

include("utils.jl")

end