abstract SyntaxNode
abstract INSTANCE <: SyntaxNode

type IDENTIFIER <: INSTANCE
    span::Int
    val::Symbol
end

type LITERAL{K} <: INSTANCE
    span::Int
    val::String
end

type KEYWORD{K} <: INSTANCE
    span::Int
end

type OPERATOR{P,K,dot} <: INSTANCE
    span::Int
end

type PUNCTUATION{K} <: INSTANCE
    span::Int
end

type HEAD{K} <: INSTANCE
    span::Int
end

type ERROR{K} <: SyntaxNode
    span::Int
end

function LITERAL(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    if ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING
        return parse_string(ps)
    else
        LITERAL{ps.t.kind}(span, ps.t.val)
    end
end

function INSTANCE(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    return isidentifier(ps.t) ? IDENTIFIER(span, Symbol(ps.t.val)) : 
        isliteral(ps.t) ? LITERAL(ps) :
        iskw(ps.t) ? KEYWORD{ps.t.kind}(span) :
        isoperator(ps.t) ? OPERATOR{precedence(ps.t),ps.t.kind,ps.dot}(span) :
        ispunctuation(ps.t) ? PUNCTUATION{ps.t.kind}(span) :
        ps.t.kind == Tokens.SEMICOLON ? PUNCTUATION{ps.t.kind}(span) : error("Can't make a token from $(ps.t)")
        # ERROR{ps.t.kind}(0)
end


type QUOTENODE <: SyntaxNode
    val::SyntaxNode
    span::Int
    punctuation::Vector{SyntaxNode}
end
QUOTENODE(val::SyntaxNode) = QUOTENODE(val, val.span, [])

# heads

const NOTHING = LITERAL{nothing}(0, "")
const BLOCK = HEAD{Tokens.BLOCK}(0)
const CALL = HEAD{Tokens.CALL}(0)
const CCALL = HEAD{Tokens.CCALL}(0)
const COMPARISON = HEAD{Tokens.COMPARISON}(0)
const COMPREHENSION = HEAD{Tokens.COMPREHENSION}(0)
const CURLY = HEAD{Tokens.CURLY}(0)
const DICT_COMPREHENSION = HEAD{Tokens.DICT_COMPREHENSION}(0)
const FILTER = HEAD{Tokens.FILTER}(0)
const GENERATOR = HEAD{Tokens.GENERATOR}(0)
const HCAT = HEAD{Tokens.HCAT}(0)
const IF = HEAD{Tokens.IF}(0)
const KW = HEAD{Tokens.KW}(0)
const LINE = HEAD{Tokens.LINE}(0)
const MACROCALL = HEAD{Tokens.MACROCALL}(0)
const PARAMETERS = HEAD{Tokens.PARAMETERS}(0)
const QUOTE = HEAD{Tokens.QUOTE}(0)
const REF = HEAD{Tokens.REF}(0)
const ROW = HEAD{Tokens.ROW}(0)
const STRING = HEAD{Tokens.STRING}(0)
const TOPLEVEL = HEAD{Tokens.TOPLEVEL}(0)
const TUPLE = HEAD{Tokens.TUPLE}(0)
const TYPED_COMPREHENSION = HEAD{Tokens.TYPED_COMPREHENSION}(0)
const TYPED_HCAT = HEAD{Tokens.TYPED_HCAT}(0)
const TYPED_VCAT = HEAD{Tokens.TYPED_VCAT}(0)
const VCAT = HEAD{Tokens.VCAT}(0)
const VECT = HEAD{Tokens.VECT}(0)

# Misc items
const x_STR = HEAD{Tokens.KEYWORD}(1)

const TRUE = LITERAL{Tokens.TRUE}(0, "")
const FALSE = LITERAL{Tokens.FALSE}(0, "")
const AT_SIGN = PUNCTUATION{Tokens.AT_SIGN}(1)
const GlobalRefDOC = HEAD{:globalrefdoc}(0)

type Scope{t}
    id
    args::Vector
end

type File
    imports
    includes
    path::String
    ast::SyntaxNode
end

type Project
    path::String
    files::Vector{File}
end


Scope() = Scope{nothing}(nothing, [])

type Variable
    id
    t
    val
end

type EXPR <: SyntaxNode
    head::SyntaxNode
    args::Vector{SyntaxNode}
    span::Int
    punctuation::Vector{SyntaxNode}
    scope::Scope
end

EXPR(head, args) = EXPR(head, args, 0, [], Scope())
EXPR(head, args, span::Int) = EXPR(head, args, span, [], Scope())
EXPR(head, args, span::Int, puncs) = EXPR(head, args, span, puncs, Scope())