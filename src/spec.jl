abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract KEYWORD <: Expression
abstract OPERATOR{P} <: Expression
abstract PUNCTUATION <: Expression
abstract HEAD <: Expression

type LOCATION
    start::Int
    stop::Int
end

type INSTANCE{T,K} <: Expression
    val::String
    ws::String
    span::Int
end

function INSTANCE(ps::ParseState)
    t = isidentifier(ps.t) ? IDENTIFIER : 
        isliteral(ps.t) ? LITERAL :
        iskw(ps.t) ? KEYWORD :
        isoperator(ps.t) ? OPERATOR{precedence(ps.t)} :
        ispunctuation(ps.t) ? PUNCTUATION :
        error("Couldn't make an INSTANCE from $(ps)")
    loc = LOCATION(ps.t.startbyte, ps.t.endbyte)
    if t==IDENTIFIER
        if ps.t.val in keys(ps.ids)
            push!(ps.ids[ps.t.val], loc)
        else
            ps.ids[ps.t.val] = [loc]
        end
    end

    return INSTANCE{t,ps.t.kind}(ps.t.val, ps.ws.val, ps.ws.endbyte-ps.t.startbyte)
end
INSTANCE(str::String) = INSTANCE{0,Tokens.ERROR}(str, "", 0)

type QUOTENODE <: Expression
    val::Expression
    span::Int
end

# heads
const emptyinstance = INSTANCE("")
const NOTHING = INSTANCE("nothing")
const BLOCK = INSTANCE("block")

const CALL = INSTANCE{HEAD,Tokens.KEYWORD}("call", "", 0)
const CURLY = INSTANCE{HEAD,Tokens.KEYWORD}("curly", "", 0)
const REF = INSTANCE{HEAD,Tokens.KEYWORD}("ref", "", 0)
const COMPARISON = INSTANCE{HEAD,Tokens.KEYWORD}("comparison", "", 0)
const IF = INSTANCE{HEAD,Tokens.IF}("if", "", 0)
const TUPLE = INSTANCE{HEAD,Tokens.KEYWORD}("tuple", "", 0)
const VECT = INSTANCE{HEAD,Tokens.KEYWORD}("vect", "", 0)
const MACROCALL = INSTANCE{HEAD,Tokens.KEYWORD}("macrocall", "", 0)
const GENERATOR = INSTANCE{HEAD,Tokens.KEYWORD}("generator", "", 0)
const TOPLEVEL = INSTANCE{HEAD,Tokens.KEYWORD}("toplevel", "", 0)
const COMPREHENSION = INSTANCE{HEAD,Tokens.KEYWORD}("comprehension", "", 0)

const TRUE = INSTANCE{LITERAL,Tokens.TRUE}("true", "", 0)
const FALSE = INSTANCE{LITERAL,Tokens.FALSE}("false", "", 0)

const AT_SIGN = INSTANCE{PUNCTUATION,Tokens.AT_SIGN}("@", "", 1)

type EXPR <: Expression
    head::Expression
    args::Vector{Expression}
    span::Int
    punctuation::Vector{Expression}
end

EXPR(head, args) = EXPR(head, args, 0)
EXPR(head, args, span::Int) = EXPR(head, args, span, [])