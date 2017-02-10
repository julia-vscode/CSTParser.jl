abstract Expression

abstract IDENTIFIER <: Expression
abstract LITERAL <: Expression
abstract KEYWORD <: Expression
abstract OPERATOR{P} <: Expression
abstract PUNCTUATION <: Expression
abstract HEAD <: Expression

type INSTANCE{T,K} <: Expression
    span::Int
end

function INSTANCE(ps::ParseState)
    t = isidentifier(ps.t) ? IDENTIFIER : 
        isliteral(ps.t) ? LITERAL :
        iskw(ps.t) ? KEYWORD :
        isoperator(ps.t) ? OPERATOR{precedence(ps.t)} :
        ispunctuation(ps.t) ? PUNCTUATION :
        error("Couldn't make an INSTANCE from $(ps)")

    return INSTANCE{t,ps.t.kind}(ps.ws.endbyte-ps.t.startbyte+1)
end
INSTANCE(str::String) = INSTANCE{0,Tokens.ERROR}(0)

type QUOTENODE <: Expression
    val::Expression
    span::Int
end

# heads

const NOTHING = INSTANCE{LITERAL,nothing}(0)
const BLOCK = INSTANCE{HEAD,Tokens.BLOCK}(0)
const CALL = INSTANCE{HEAD,Tokens.CALL}(0)
const CCALL = INSTANCE{HEAD,Tokens.CCALL}(0)
const COMPARISON = INSTANCE{HEAD,Tokens.COMPARISON}(0)
const COMPREHENSION = INSTANCE{HEAD,Tokens.COMPREHENSION}(0)
const CURLY = INSTANCE{HEAD,Tokens.CURLY}(0)
const GENERATOR = INSTANCE{HEAD,Tokens.GENERATOR}(0)
const KW = INSTANCE{HEAD,Tokens.KW}(0)
const LINE = INSTANCE{HEAD,Tokens.LINE}(0)
const MACROCALL = INSTANCE{HEAD,Tokens.MACROCALL}(0)
const PARAMETERS = INSTANCE{HEAD,Tokens.PARAMETERS}(0)
const REF = INSTANCE{HEAD,Tokens.REF}(0)
const TOPLEVEL = INSTANCE{HEAD,Tokens.TOPLEVEL}(0)
const TUPLE = INSTANCE{HEAD,Tokens.TUPLE}(0)
const TYPED_COMPREHENSION = INSTANCE{HEAD,Tokens.TYPED_COMPREHENSION}(0)
const VCAT = INSTANCE{HEAD,Tokens.VCAT}(0)
const VECT = INSTANCE{HEAD,Tokens.VECT}(0)

const TRUE = INSTANCE{LITERAL,Tokens.TRUE}(0)
const FALSE = INSTANCE{LITERAL,Tokens.FALSE}(0)
const AT_SIGN = INSTANCE{PUNCTUATION,Tokens.AT_SIGN}(1)

type EXPR <: Expression
    head::Expression
    args::Vector{Expression}
    span::Int
    punctuation::Vector{Expression}
end

EXPR(head, args) = EXPR(head, args, 0)
EXPR(head, args, span::Int) = EXPR(head, args, span, [])