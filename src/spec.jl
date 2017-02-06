abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract BOOL <: Expression
abstract KEYWORD <: Expression
abstract OPERATOR{P} <: Expression
abstract DELIMINATOR <: Expression

type LOCATION
    start::Int
    stop::Int
end
const emptyloc = LOCATION(-1, -1)

type INSTANCE{T} <: Expression
    val::String
    ws::String
    span::Int
end

function INSTANCE(ps::ParseState)
    t = isidentifier(ps.t) ? IDENTIFIER : 
        isliteral(ps.t) ? LITERAL :
        iskw(ps.t) ? KEYWORD :
        isoperator(ps.t) ? OPERATOR{precedence(ps.t)} :
        error("Couldn't make an INSTANCE from $(ps.t.val)")
    loc = LOCATION(ps.t.startbyte, ps.t.endbyte)
    if t==IDENTIFIER
        if ps.t.val in keys(ps.ids)
            push!(ps.ids[ps.t.val], loc)
        else
            ps.ids[ps.t.val] = [loc]
        end
    end

    return INSTANCE{t}(ps.t.val, ps.ws.val, ps.ws.endbyte-ps.t.startbyte)
end
INSTANCE(str::String) = INSTANCE{0}(str, "", 0)

type QUOTENODE <: Expression
    val::Expression
end

# heads
const emptyinstance = INSTANCE("")
const NOTHING = INSTANCE("nothing")
const BLOCK = INSTANCE("block")
const CALL = INSTANCE("call")
const CURLY = INSTANCE("curly")
const REF = INSTANCE("ref")
const COMPARISON = INSTANCE("comparison")
const IF = INSTANCE("if")
const TUPLE = INSTANCE("tuple")
const VECT = INSTANCE("vect")
const MACROCALL = INSTANCE("macrocall")
const GENERATOR = INSTANCE("generator")
const COMPREHENSION = INSTANCE("comprehension")
const TRUE = INSTANCE{LITERAL}("true", "", 0)
const FALSE = INSTANCE{LITERAL}("false", "", 0)

type EXPR <: Expression
    head::Expression
    args::Vector{Expression}
    span::Int
end

EXPR(head, args) = EXPR(head, args, 0)