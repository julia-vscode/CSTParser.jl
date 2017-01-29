abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract BOOL <: Expression
abstract KEYWORD <: Expression
abstract OPERATOR <: Expression

type INSTANCE{T} <: Expression
    start::Int
    stop::Int
    val::String
    ws::String
end

function INSTANCE(ps::ParseState)
    t = isidentifier(ps.t) ? IDENTIFIER : 
        isliteral(ps.t) ? LITERAL :
        iskw(ps.t) ? KEYWORD :
        isoperator(ps.t) ? OPERATOR :
        error("Couldn't make an INSTANCE from $(ps.t.val)")

    return INSTANCE{t}(ps.t.startbyte, ps.t.endbyte, ps.t.val, ps.ws.val)
end


type CURLY <: Expression
    start::Int
    stop::Int
    name::INSTANCE
    args::Vector{Expression}
end

    
type LIST{t} <: Expression
    start::Int
    stop::Int
    opener::INSTANCE
    args::Vector{Expression}
    closer::INSTANCE
end

type BLOCK <: Expression
    start::Int
    stop::Int
    oneliner::Bool
    args::Vector{Expression}
end
BLOCK() = BLOCK(0, 0, false, [])

type CALL <: Expression
    start::Int
    stop::Int
    name::Expression
    args::Vector{Expression}
    prec::Int
end

type CHAIN{T} <: OPERATOR
    start::Int
    stop::Int
    args::Vector{Expression}
end

typealias COMPARISON CHAIN{6}

type KEYWORD_BLOCK{Nargs} <: Expression
    start::Int
    stop::Int
    opener::INSTANCE{KEYWORD}
    args::Vector{Expression}
    closer
end
