import Base.Expr

abstract Expression
    
type Identifier <: Expression
    val::Symbol
    ws::String
    loc::Tuple{Int,Int}
    Identifier(ps::ParseState) = new(Symbol(ps.t.val), ps.ws.val, (ps.t.startbyte, ps.t.endbyte))
end

type Literal <: Expression
    val::String
    ws::String
    loc::Tuple{Int,Int}
    Literal(ps::ParseState) = new(ps.t.val, ps.ws.val, (ps.t.startbyte, ps.t.endbyte))
end

type Operator <: Expression
    val::String
    ws::String
    loc::Tuple{Int,Int}
    precedence::Int
    Operator(ps::ParseState) = new(ps.t.val, ps.ws.val, (ps.t.startbyte, ps.t.endbyte), precedence(ps.t))
end
precedence(op::Operator) = op.precedence


type Parentheses <: Expression
    loc::Tuple{Int,Int}
    args::Vector{Expression}
end

# kws not handled
type FunctionCall <: Expression
    name::Expression
    args::Vector{Expression}
end
precedence(fc::FunctionCall) = fc.name isa Operator ? fc.name.precedence : 0

type FunctionDef <: Expression
    oneliner::Bool
    fcall::FunctionCall
    body::Vector{Expression}
end

type typealiasDef <: Expression
    name::Identifier
    body::Expression
end

type bitstypeDef <: Expression
    bits::Expression
    name::Expression
end






# Conversion
Expr(x::Identifier) = x.val
Expr(x::Literal) = Base.parse(x.val)
Expr(x::Operator) = Symbol(x.val)
function Expr(x::FunctionCall)
    if x.name.val in ["||", "&&", "::"]
        return Expr(Symbol(x.name.val), Expr.(x.args)...)
    end

    return Expr(:call, Expr(x.name), Expr.(x.args)...)
end

Expr{T<:Expression}(x::Vector{T}) = Expr(:block, Expr.(x)...)

function Expr(x::FunctionDef) 
    if x.oneliner
        return Expr(:(=), Expr(x.fcall), Expr(x.body))
    end
end
Expr(x::typealiasDef) = Expr(:typealias, Expr(x.name), Expr(x.body))
Expr(x::bitstypeDef) = Expr(:bitstype, Expr(x.bits), Expr(x.name))

