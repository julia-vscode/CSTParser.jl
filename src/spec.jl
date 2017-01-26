abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract BOOL <: Expression
abstract KEYWORD <: Expression

type INSTANCE{T} <: Expression
    span::Int
    val::String
    ws::String
end

function INSTANCE(ps::ParseState)
    t = isidentifier(ps.t) ? IDENTIFIER : 
        isliteral(ps.t) ? LITERAL :
        isbool(ps.t) ? BOOL : 
        iskw(ps.t) ? KEYWORD :
        error("Couldn't make an INSTANCE from $(ps.t.val)")

    return INSTANCE{t}(span(ps.t), Symbol(ps.t.val), ps.ws.val)
end


type OPERATOR <: Expression
    span::Int
    val::String
    ws::String
    precedence::Int
end
OPERATOR(ps::ParseState) = OPERATOR(span(ps.t), ps.t.val, ps.ws.val, precedence(ps.t))


type CURLY <: Expression
    name::INSTANCE
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
    name::Expression
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

type KEYWORD_BLOCK{Nargs} <: Expression
    span::Int
    opener::INSTANCE{KEYWORD}
    args::Vector{Expression}
    closer
end
