# Operator hierarchy
const AssignmentOp  = 1
const ConditionalOp = 3
const ArrowOp       = 4
const LazyOrOp      = 5
const LazyAndOp     = 6
const ComparisonOp  = 7
const PipeOp        = 8
const ColonOp       = 9
const PlusOp        = 10
const BitShiftOp    = 11
const TimesOp       = 12
const RationalOp    = 13
const PowerOp       = 14
const DeclarationOp = 15
const WhereOp       = 16
const DotOp         = 17
const PrimeOp       = 17
const DddotOp       = 8
const AnonFuncOp    = 15

abstract type AbstractEXPR end

# Invariants:
# if !isempty(e.args)
#   e.fullspan == sum(x->x.fullspan, e.args)
#   first(e.span) == first(first(e.args).span)
#   last(e.span) == sum(x->x.fullspan, e.args[1:end-1]) + last(last(e.args).span)
# end
mutable struct EXPR{T} <: AbstractEXPR
    args::Vector
    # The full width of this expression including any whitespace
    fullspan::Int
    # The range of bytes within the fullspan that constitute the actual expression,
    # excluding any leading/trailing whitespace or other trivia. 1-indexed
    span::UnitRange{Int}
end


abstract type LeafNode <: AbstractEXPR end
    
struct IDENTIFIER <: LeafNode
    fullspan::Int
    span::UnitRange{Int}
    val::String
    IDENTIFIER(fullspan::Int, span::UnitRange{Int}, val::String) = new(fullspan, span, val)
end
@noinline IDENTIFIER(ps::ParseState) = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1), val(ps.t, ps))

struct PUNCTUATION <: LeafNode
    kind::Tokenize.Tokens.Kind
    fullspan::Int
    span::UnitRange{Int}
end
@noinline PUNCTUATION(ps::ParseState) = PUNCTUATION(ps.t.kind, ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1))

struct OPERATOR <: LeafNode
    fullspan::Int
    span::UnitRange{Int}
    kind::Tokenize.Tokens.Kind
    dot::Bool
end
@noinline OPERATOR(ps::ParseState) = OPERATOR(ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1), ps.t.kind, ps.t.dotop)

struct KEYWORD <: LeafNode
    kind::Tokenize.Tokens.Kind
    fullspan::Int
    span::UnitRange{Int}
end
@noinline KEYWORD(ps::ParseState) = KEYWORD(ps.t.kind, ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1))


struct LITERAL <: LeafNode
    fullspan::Int
    span::UnitRange{Int}
    val::String
    kind::Tokenize.Tokens.Kind
end
function LITERAL(ps::ParseState)
    if ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING ||
       ps.t.kind == Tokens.CMD || ps.t.kind == Tokens.TRIPLE_CMD
        return parse_string_or_cmd(ps)
    else
        LITERAL(ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1), val(ps.t, ps), ps.t.kind)
    end
end

# AbstractTrees.children(x::EXPR) = x.args

span(x::AbstractEXPR) = length(x.span)

function update_span!(x) end
function update_span!(x::EXPR)
    isempty(x.args) && return
    x.fullspan = 0
    for a in x.args
        x.fullspan += a.fullspan
    end
    x.span = first(first(x.args).span):(x.fullspan - last(x.args).fullspan + last(last(x.args).span))
    return 
end

function EXPR{T}(args::Vector) where {T}
    ret = EXPR{T}(args, 0, 1:0)
    update_span!(ret)
    ret
end

function Base.push!(e::EXPR, arg)
    e.span = first(e.span):(e.fullspan + last(arg.span))
    e.fullspan += arg.fullspan
    push!(e.args, arg)
end

function Base.pushfirst!(e::EXPR, arg)
    e.fullspan += arg.fullspan
    e.span = first(arg.span):last(e.span)
    pushfirst!(e.args, arg)
end

function Base.pop!(e::EXPR)
    arg = pop!(e.args)
    e.fullspan -= arg.fullspan
    if isempty(e.args)
        e.span = 1:0
    else
        e.span = first(e.span):(e.fullspan - last(e.args).fullspan + last(last(e.args).span))
    end
    arg
end

function Base.append!(e::EXPR, args::Vector)
    append!(e.args, args)
    update_span!(e)
end

function Base.append!(a::EXPR, b::EXPR)
    append!(a.args, b.args)
    a.fullspan += b.fullspan
    a.span = first(a.span):last(b.span)
end

function Base.append!(a::EXPR, b::KEYWORD)
    append!(a.args, b.args)
    a.fullspan += b.fullspan
    a.span = first(a.span):last(b.span)
end

function INSTANCE(ps::ParseState)
    if isidentifier(ps.t)
        return IDENTIFIER(ps)
    elseif isliteral(ps.t)
        return LITERAL(ps)
    elseif iskw(ps.t)
        return KEYWORD(ps)
    elseif isoperator(ps.t)
        return OPERATOR(ps)
    elseif ispunctuation(ps.t)
        return PUNCTUATION(ps)
    else
        return ErrorToken()
    end
end


mutable struct File
    imports
    includes::Vector{Tuple{String,Any}}
    path::String
    ast::EXPR
    errors
end
File(path::String) = File([], [], path, EXPR{FileH}(Any[]), [])

mutable struct Project
    path::String
    files::Vector{File}
end

abstract type Head end
abstract type Call <: Head end

mutable struct UnaryOpCall <: AbstractEXPR
    op::OPERATOR
    arg
    fullspan::Int
    span::UnitRange{Int}
    function UnaryOpCall(op, arg)
        fullspan = op.fullspan + arg.fullspan
        new(op, arg, fullspan, 1:(fullspan - arg.fullspan + length(arg.span)))
    end
end

mutable struct UnarySyntaxOpCall <: AbstractEXPR
    arg1
    arg2
    fullspan::Int
    span::UnitRange{Int}
    function UnarySyntaxOpCall(arg1, arg2)
        fullspan = arg1.fullspan + arg2.fullspan
        new(arg1, arg2, fullspan, 1:(fullspan - arg2.fullspan + length(arg2.span)))
    end
end

mutable struct BinaryOpCall <: AbstractEXPR
    arg1
    op::OPERATOR
    arg2
    fullspan::Int
    span::UnitRange{Int}
    function BinaryOpCall(arg1, op, arg2)
        fullspan = arg1.fullspan + op.fullspan + arg2.fullspan
        new(arg1, op, arg2, fullspan, 1:(fullspan - arg2.fullspan + length(arg2.span)))
    end
end

mutable struct BinarySyntaxOpCall <: AbstractEXPR
    arg1
    op::OPERATOR
    arg2
    fullspan::Int
    span::UnitRange{Int}
    function BinarySyntaxOpCall(arg1, op, arg2)
        fullspan = arg1.fullspan + op.fullspan + arg2.fullspan
        new(arg1, op, arg2, fullspan, 1:(fullspan - arg2.fullspan + length(arg2.span)))
    end
end

mutable struct WhereOpCall <: AbstractEXPR
    arg1
    op::OPERATOR
    args::Vector
    fullspan::Int
    span::UnitRange{Int}
    function WhereOpCall(arg1, op::OPERATOR, args)
        fullspan = arg1.fullspan + op.fullspan
        for a in args
            fullspan += a.fullspan
        end
        new(arg1, op, args, fullspan, 1:(fullspan - last(args).fullspan + length(last(args).span)))
    end
end

mutable struct ConditionalOpCall <: AbstractEXPR
    cond
    op1::OPERATOR
    arg1
    op2::OPERATOR
    arg2
    fullspan::Int
    span::UnitRange{Int}
    function ConditionalOpCall(cond, op1, arg1, op2, arg2)
        fullspan = cond.fullspan + op1.fullspan + arg1.fullspan + op2.fullspan + arg2.fullspan
        new(cond, op1, arg1, op2, arg2, fullspan, 1:(fullspan - arg2.fullspan + length(arg2.span)))
    end
end

abstract type ComparisonOpCall <: Head end
abstract type ChainOpCall <: Head end
abstract type ColonOpCall <: Head end
abstract type Abstract <: Head end
abstract type Begin <: Head end
# abstract type Bitstype <: Head end
abstract type Block <: Head end
abstract type Braces <: Head end
abstract type BracesCat <: Head end
abstract type Const <: Head end
abstract type Comparison <: Head end
abstract type Curly <: Head end
abstract type Do <: Head end
abstract type Filter <: Head end
abstract type Flatten <: Head end
abstract type For <: Head end
abstract type FunctionDef <: Head end
abstract type Generator <: Head end
abstract type Global <: Head end
abstract type GlobalRefDoc <: Head end
abstract type If <: Head end
abstract type Kw <: Head end
abstract type Let <: Head end
abstract type Local <: Head end
abstract type Macro <: Head end
abstract type MacroCall <: Head end
abstract type MacroName <: Head end
abstract type Mutable <: Head end
abstract type Outer <: Head end
abstract type Parameters <: Head end
abstract type Primitive <: Head end
abstract type Quote <: Head end
abstract type Quotenode <: Head end
abstract type InvisBrackets <: Head end
abstract type StringH <: Head end
abstract type Struct <: Head end
abstract type Try <: Head end
abstract type TupleH <: Head end
# abstract type TypeAlias <: Head end
abstract type FileH <: Head end
abstract type Return <: Head end
abstract type While <: Head end
abstract type x_Cmd <: Head end
abstract type x_Str <: Head end

abstract type ModuleH <: Head end
abstract type BareModule <: Head end
abstract type TopLevel <: Head end
abstract type Export <: Head end
abstract type Import <: Head end
abstract type ImportAll <: Head end
abstract type Using <: Head end

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

abstract type ErrorToken <: Head end
ErrorToken() = EXPR{ErrorToken}([], 0, 0:0)
ErrorToken(x) = EXPR{ErrorToken}([x])

Quotenode(x) = EXPR{Quotenode}(Any[x])

const TRUE = LITERAL(0, 1:0, "", Tokens.TRUE)
const FALSE = LITERAL(0, 1:0, "", Tokens.FALSE)
const NOTHING = LITERAL(0, 1:0, "", Tokens.NOTHING)

const GlobalRefDOC = EXPR{GlobalRefDoc}(Any[], 0, 1:0)
