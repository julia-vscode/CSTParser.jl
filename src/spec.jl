abstract Expression
abstract INSTANCE <: Expression

type IDENTIFIER <: INSTANCE
    span::Int
    offset::Int
    val::Symbol
end

type LITERAL{K} <: INSTANCE
    span::Int
    offset::Int
end

type KEYWORD{K} <: INSTANCE
    span::Int
    offset::Int
end

type OPERATOR{P,K,dot} <: INSTANCE
    span::Int
    offset::Int
end

type PUNCTUATION{K} <: INSTANCE
    span::Int
    offset::Int
end

type HEAD{K} <: INSTANCE
    span::Int
    offset::Int
end

function INSTANCE(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    offset = ps.t.startbyte
    return isidentifier(ps.t) ? IDENTIFIER(span, offset, Symbol(ps.t.val)) : 
        isliteral(ps.t) ? LITERAL{ps.t.kind}(span, offset) :
        iskw(ps.t) ? KEYWORD{ps.t.kind}(span, offset) :
        isoperator(ps.t) ? OPERATOR{precedence(ps.t),ps.t.kind,ps.dot}(span + ps.dot, offset - ps.dot) :
        ispunctuation(ps.t) ? PUNCTUATION{ps.t.kind}(span, offset) :
        ps.t.kind == Tokens.SEMICOLON ? PUNCTUATION{ps.t.kind}(span, offset) :
        error("Couldn't make an INSTANCE from $(ps)")
end


type QUOTENODE <: Expression
    val::Expression
    span::Int
    punctuation::Vector{INSTANCE}
end

# heads

const NOTHING = LITERAL{nothing}(0, 0)
const BLOCK = HEAD{Tokens.BLOCK}(0, 0)
const CALL = HEAD{Tokens.CALL}(0, 0)
const CCALL = HEAD{Tokens.CCALL}(0, 0)
const COMPARISON = HEAD{Tokens.COMPARISON}(0, 0)
const COMPREHENSION = HEAD{Tokens.COMPREHENSION}(0, 0)
const CURLY = HEAD{Tokens.CURLY}(0, 0)
const GENERATOR = HEAD{Tokens.GENERATOR}(0, 0)
const IF = HEAD{Tokens.IF}(0, 0)
const KW = HEAD{Tokens.KW}(0, 0)
const LINE = HEAD{Tokens.LINE}(0, 0)
const MACROCALL = HEAD{Tokens.MACROCALL}(0, 0)
const PARAMETERS = HEAD{Tokens.PARAMETERS}(0, 0)
const QUOTE = HEAD{Tokens.QUOTE}(0, 0)
const REF = HEAD{Tokens.REF}(0, 0)
const TOPLEVEL = HEAD{Tokens.TOPLEVEL}(0, 0)
const TUPLE = HEAD{Tokens.TUPLE}(0, 0)
const TYPED_COMPREHENSION = HEAD{Tokens.TYPED_COMPREHENSION}(0, 0)
const VCAT = HEAD{Tokens.VCAT}(0, 0)
const VECT = HEAD{Tokens.VECT}(0, 0)

# Misc items
const x_STR = HEAD{Tokens.KEYWORD}(1, 0)

const TRUE = LITERAL{Tokens.TRUE}(0, 0)
const FALSE = LITERAL{Tokens.FALSE}(0, 0)
const AT_SIGN = PUNCTUATION{Tokens.AT_SIGN}(1, 0)
const GlobalRefDOC = HEAD{:globalrefdoc}(0, 0)


type EXPR <: Expression
    head::Expression
    args::Vector{Expression}
    span::Int
    punctuation::Vector{INSTANCE}
end

EXPR(head, args) = EXPR(head, args, 0)
EXPR(head, args, span::Int) = EXPR(head, args, span, [])