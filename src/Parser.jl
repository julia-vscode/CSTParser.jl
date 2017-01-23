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
    elseif ps.t.kind == Tokens.IDENTIFIER &&
                        ps.nt.kind == Tokens.LPAREN
        ret = parse_function(ps)
    elseif Tokens.begin_literal < ps.t.kind < Tokens.end_literal
        if Tokens.begin_ops < ps.nt.kind < Tokens.end_ops
            ret = Literal(ps)
        end
    elseif ps.t.kind == Tokens.IDENTIFIER
        if Tokens.begin_ops < ps.nt.kind < Tokens.end_ops
            ret = Identifier(ps)
        end
    end

    if isbinaryop(ps.nt)
        op = Operator(next(ps))
        nexta = parse_expression(ps, closer_no_ops)
        ret = FunctionCall(op, [ret, nexta])
        lastcall = ret
        last_op_precedence = precedence(op)
        while isbinaryop(ps.nt)
            next(ps)
            op = Operator(ps)
            nexta = parse_expression(ps, closer_no_ops)
            if precedence(op) <= last_op_precedence 
                if lastcall.name.val==op.val && ischainable(op)
                    push!(lastcall.args, nexta)
                else
                    ret = FunctionCall(op,[ret, nexta])
                    lastcall = ret
                end
            else
                if lastcall.name.val==op.val && ischainable(op)
                    push!(lastcall.args, nexta)
                else
                    lastcall.args[end] = FunctionCall(op, [lastcall.args[end], nexta])
                    lastcall = lastcall.args[end]
                end
            end
            last_op_precedence = precedence(op)
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