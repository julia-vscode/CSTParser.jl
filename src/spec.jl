abstract type SyntaxNode end
abstract type INSTANCE <: SyntaxNode end

mutable struct IDENTIFIER <: INSTANCE
    span::Int
    val::Symbol
end

mutable struct LITERAL{K} <: INSTANCE
    span::Int
    val::String
end

mutable struct KEYWORD{K} <: INSTANCE
    span::Int
end

mutable struct OPERATOR{P,K,dot} <: INSTANCE
    span::Int
end

mutable struct PUNCTUATION{K} <: INSTANCE
    span::Int
end

mutable struct HEAD{K} <: INSTANCE
    span::Int
end

mutable struct ERROR{K} <: SyntaxNode
    span::Int
    partial::SyntaxNode
end

function LITERAL(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    if ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING
        return parse_string(ps)
    else
        LITERAL{ps.t.kind}(span, ps.t.val)
    end
end

IDENTIFIER(ps::ParseState) = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, Symbol(ps.t.val))

OPERATOR(ps::ParseState) = OPERATOR{precedence(ps.t),ps.t.kind,ps.dot}(ps.nt.startbyte - ps.t.startbyte)

KEYWORD(ps::ParseState) = KEYWORD{ps.t.kind}(ps.nt.startbyte - ps.t.startbyte)

PUNCTUATION(ps::ParseState) = PUNCTUATION{ps.t.kind}(ps.nt.startbyte - ps.t.startbyte)

function INSTANCE(ps::ParseState)
    span = ps.nt.startbyte - ps.t.startbyte
    return isidentifier(ps.t) ? IDENTIFIER(ps) : 
        isliteral(ps.t) ? LITERAL(ps) :
        iskw(ps.t) ? KEYWORD(ps) :
        isoperator(ps.t) ? OPERATOR(ps) :
        ispunctuation(ps.t) ? PUNCTUATION{ps.t.kind}(span) :
        ps.t.kind == Tokens.SEMICOLON ? PUNCTUATION{ps.t.kind}(span) : 
        ERROR{ps.t.kind}(0, NOTHING)
end


mutable struct QUOTENODE <: SyntaxNode
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
const CELL1D = HEAD{Tokens.LBRACE}(0)
const COMPARISON = HEAD{Tokens.COMPARISON}(0)
const COMPREHENSION = HEAD{Tokens.COMPREHENSION}(0)
const CURLY = HEAD{Tokens.CURLY}(0)
const DICT_COMPREHENSION = HEAD{Tokens.DICT_COMPREHENSION}(0)
const FILTER = HEAD{Tokens.FILTER}(0)
const FLATTEN = HEAD{Tokens.FLATTEN}(0)
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
const x_STR = HEAD{Tokens.x_STR}(1)
const x_CMD = HEAD{Tokens.x_CMD}(1)
const FILE = HEAD{:file}(0)

const TRUE = LITERAL{Tokens.TRUE}(0, "")
const FALSE = LITERAL{Tokens.FALSE}(0, "")
const AT_SIGN = PUNCTUATION{Tokens.AT_SIGN}(1)
const GlobalRefDOC = HEAD{:globalrefdoc}(0)


abstract type Scope{t} end

mutable struct File
    imports
    includes::Vector{Tuple{String,Any}}
    path::String
    ast::SyntaxNode
    errors
end
File(path::String) = File([], [], path, EXPR(FILE, []), [])

mutable struct Project
    path::String
    files::Vector{File}
end

mutable struct Variable
    id
    t
    val::SyntaxNode
end

const NoVariable = Variable(NOTHING, NOTHING, NOTHING)

abstract type Head end

abstract type Call <: Head end
abstract type UnaryOpCall <: Head end
abstract type UnarySyntaxOpCall <: Head end
abstract type BinaryOpCall <: Head end
abstract type BinarySyntaxOpCall <: Head end
abstract type ConditionalOpCall <: Head end
abstract type ComparisonOpCall <: Head end
abstract type ChainOpCall <: Head end
abstract type ColonOpCall <: Head end

abstract type Abstract <: Head end
abstract type Begin <: Head end
abstract type Bitstype <: Head end
abstract type Block <: Head end
abstract type Break <: Head end
abstract type Cell1d <: Head end
abstract type Const <: Head end
abstract type Continue <: Head end
abstract type Comparison <: Head end
abstract type Curly <: Head end
abstract type Do <: Head end
abstract type Filter <: Head end
abstract type Flatten <: Head end
abstract type For <: Head end
abstract type FunctionDef <: Head end
abstract type Generator <: Head end
abstract type Global <: Head end
abstract type If <: Head end
abstract type Kw <: Head end
abstract type Let <: Head end
abstract type Local <: Head end
abstract type Macro <: Head end
abstract type MacroCall <: Head end
abstract type Mutable <: Head end
abstract type Parameters <: Head end
abstract type Primitive <: Head end
abstract type Quote <: Head end
abstract type InvisBrackets <: Head end
abstract type StringH <: Head end
abstract type Struct <: Head end
abstract type Try <: Head end
abstract type TupleH <: Head end
abstract type TypeAlias <: Head end
abstract type FileH <: Head end
abstract type TopLevel <: Head end
abstract type Return <: Head end
abstract type Vect <: Head end
abstract type While <: Head end
abstract type x_Cmd <: Head end
abstract type x_Str <: Head end

abstract type Import <: Head end
abstract type ImportAll <: Head end
abstract type Using <: Head end
abstract type Export <: Head end

abstract type Comprehension <: Head end
abstract type DictComprehension <: Head end
abstract type TypedComprehension <: Head end
abstract type Hcat <: Head end
abstract type TypedHcat <: Head end
abstract type Ref <: Head end
abstract type Row <: Head end
abstract type Vcat <: Head end
abstract type TypedVcat <: Head end
abstract type Vect <: Head end




mutable struct EXPR{T} <: SyntaxNode
    args::Vector{SyntaxNode}
    span::Int
    defs::Vector{Variable}
end



EXPR(T, args) = EXPR{T}(args, 0, [])
EXPR(T, args, span::Int) = EXPR{T}(args, span, [])

