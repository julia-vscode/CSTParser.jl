abstract Expression

abstract INSTANCE <: Expression
function INSTANCE(ps::ParseState)
    if isidentifier(ps.t)
        return IDENTIFIER(ps)
    elseif isliteral(ps.t)
        return LITERAL(ps)
    else
        error("not instance at $(ps.l.token_start_row):$(ps.l.token_startpos)")
    end
end

type IDENTIFIER <: INSTANCE
    val::Symbol
    ws::String
    loc::Tuple{Int,Int}
    IDENTIFIER(ps::ParseState) = new(Symbol(ps.t.val), ps.ws.val, (ps.t.startbyte, ps.t.endbyte))
end

type LITERAL <: INSTANCE
    val::String
    ws::String
    loc::Tuple{Int,Int}
    LITERAL(ps::ParseState) = new(ps.t.val, ps.ws.val, (ps.t.startbyte, ps.t.endbyte))
end

type OPERATOR <: Expression
    val::String
    ws::String
    loc::Tuple{Int,Int}
    precedence::Int
end
OPERATOR(ps::ParseState) = OPERATOR(ps.t.val, ps.ws.val, (ps.t.startbyte, ps.t.endbyte), precedence(ps.t))


type CURLY <: Expression
    name::IDENTIFIER
    args::Vector{Expression}
end

type Parentheses <: Expression
    loc::Tuple{Int,Int}
    args::Vector{Expression}
end

type BLOCK <: Expression
    oneliner::Bool
    args::Vector{Expression}
end
BLOCK() = BLOCK(false,[])



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



type RETURN{T<:Expression} <:Expression
    ws::String
    arg::T
end






abstract DATATYPE <: Expression

type TYPEALIAS <: DATATYPE
    name::IDENTIFIER
    body::Expression
end


type BITSTYPE <: DATATYPE
    bits::Expression
    name::Expression
end


type TYPE <: DATATYPE
    name::IDENTIFIER
    fields::BLOCK
end


type IMMUTABLE <: DATATYPE
    name::IDENTIFIER
    fields::BLOCK
end





type CONST <: Expression
    decl::Expression
end
type GLOBAL <: Expression
    decl::Expression
end
type LOCAL <: Expression
    decl::Expression
end


