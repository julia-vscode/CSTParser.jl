abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract BOOL <: Expression
abstract KEYWORD <: Expression
abstract OPERATOR <: Expression

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
        isoperator(ps.t) ? OPERATOR :
        error("Couldn't make an INSTANCE from $(ps.t.val)")

    return INSTANCE{t}(span(ps.t), (ps.t.val), ps.ws.val)
end


type CURLY <: Expression
    span::Int
    name::INSTANCE
    args::Vector{Expression}
end

type BLOCK <: Expression
    span::Int
    oneliner::Bool
    args::Vector{Expression}
end
BLOCK() = BLOCK(0, false, [])

type COMPARISON <: Expression
    span::Int
    args::Vector{Expression}
end

type CALL <: Expression
    span::Int
    name::Expression
    args::Vector{Expression}
    prec::Int
end

type KEYWORD_BLOCK{Nargs} <: Expression
    span::Int
    opener::INSTANCE{KEYWORD}
    args::Vector{Expression}
    closer
end
