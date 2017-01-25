abstract Expression

abstract INSTANCE <: Expression

function INSTANCE(ps::ParseState)
    if isidentifier(ps.t)
        return IDENTIFIER(ps)
    elseif isliteral(ps.t)
        return LITERAL(ps)
    elseif ps.t.kind in [Tokens.TRUE, Tokens.FALSE]
        return BOOL(ps)
    else
        error("not instance at $(ps.l.token_start_row):$(ps.l.token_startpos)")
    end
end

type IDENTIFIER <: INSTANCE
    span::Int
    val::Symbol
    ws::String
    IDENTIFIER(ps::ParseState) = new(span(ps.t), Symbol(ps.t.val), ps.ws.val)
end

type LITERAL <: INSTANCE
    span::Int
    val::String
    ws::String
    LITERAL(ps::ParseState) = new(span(ps.t), ps.t.val, ps.ws.val)
end

type BOOL <: INSTANCE
    span::Int
    val::Bool
    ws::String
    BOOL(ps::ParseState) = new(span(ps.t), ps.t.kind==Tokens.True, ps.ws.val)
end


type OPERATOR <: Expression
    span::Int
    val::String
    ws::String
    precedence::Int
end
OPERATOR(ps::ParseState) = OPERATOR(span(ps.t), ps.t.val, ps.ws.val, precedence(ps.t))


type CURLY <: Expression
    name::IDENTIFIER
    args::Vector{Expression}
end

type Parentheses <: Expression
    loc::Tuple{Int,Int}
    args::Vector{Expression}
end

type BLOCK <: Expression
    span::Int
    oneliner::Bool
    args::Vector{Expression}
end
BLOCK() = BLOCK(0, false, [])



type SYNTAXCALL <: Expression
    name::OPERATOR
    args::Vector{Expression}
end

type COMPARISON <: Expression
    args::Vector{Expression}
end


# kws not handled
type CALL <: Expression
    name::Expression
    args::Vector{Expression}
end



type FUNCTION{T} <: Expression
    oneliner::Bool
    signature::Expression
    body::T
end

type MODULE{T} <: Expression
    span::Int
    bare::Bool
    name::Expression
    body::T
end

type BAREMODULE{T} <: Expression
    bare::Bool
    name::Expression
    body::T
end




abstract DATATYPE <: Expression

type TYPEALIAS <: DATATYPE
    name::Expression
    body::Expression
end


type BITSTYPE <: DATATYPE
    bits::Expression
    name::Expression
end


type TYPE <: DATATYPE
    span::Int
    name::Expression
    fields::BLOCK
end


type IMMUTABLE <: DATATYPE
    name::IDENTIFIER
    fields::BLOCK
end





type CONST <: Expression
    span::Int
    decl::Expression
end
type GLOBAL <: Expression
    span::Int
    decl::Expression
end
type LOCAL <: Expression
    span::Int
    decl::Expression
end

type RETURN <:Expression
    span::Int
    decl::Expression
end

