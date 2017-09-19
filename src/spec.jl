# Operator hierarchy
const AssignmentOp  = 1
const ConditionalOp = 2
const ArrowOp       = 3
const LazyOrOp      = 4
const LazyAndOp     = 5
const ComparisonOp  = 6
const PipeOp        = 7
const ColonOp       = 8
const PlusOp        = 9
const BitShiftOp    = 10
const TimesOp       = 11
const RationalOp    = 12
const PowerOp       = 13
const DeclarationOp = 14
const WhereOp       = 15
const DotOp         = 16
const PrimeOp       = 16
const DddotOp       = 7
const AnonFuncOp    = 14


# Invariants:
# if !isempty(e.args)
#   e.fullspan == sum(x->x.fullspan, e.args)
#   first(e.span) == first(first(e.args).span)
#   last(e.span) == sum(x->x.fullspan, e.args[1:end-1]) + last(last(e.args).span)
# end
mutable struct EXPR{T}
    args::Vector
    # The full width of this expression including any whitespace
    fullspan::Int
    # The range of bytes within the fullspan that constitute the actual expression,
    # excluding any leading/trailing whitespace or other trivia. 1-indexed
    span::UnitRange{Int}
end

abstract type ERROR end

struct IDENTIFIER
    fullspan::Int
    span::UnitRange{Int}
    val::String
    IDENTIFIER(fullspan::Int, span::UnitRange{Int}, val::String) = new(fullspan, span, val)
end
IDENTIFIER(ps::ParseState) = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1), val(ps.t, ps))

struct PUNCTUATION
    kind::Tokenize.Tokens.Kind
    fullspan::Int
    span::UnitRange{Int}
end
PUNCTUATION(ps::ParseState) = PUNCTUATION(ps.t.kind, ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1))

struct OPERATOR
    fullspan::Int
    span::UnitRange{Int}
    kind::Tokenize.Tokens.Kind
    dot::Bool
end
OPERATOR(ps::ParseState) = OPERATOR(ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1), ps.t.kind, ps.dot)

struct KEYWORD
    kind::Tokenize.Tokens.Kind
    fullspan::Int
    span::UnitRange{Int}
end
KEYWORD(ps::ParseState) = KEYWORD(ps.t.kind, ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1))


struct LITERAL
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

AbstractTrees.children(x::EXPR) = x.args

span(x::EXPR) = length(x.span)
span(x::OPERATOR) = length(x.span)
span(x::IDENTIFIER) = length(x.span)
span(x::KEYWORD) = length(x.span)
span(x::PUNCTUATION) = length(x.span)
span(x::LITERAL) = length(x.span)

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

function Base.unshift!(e::EXPR, arg)
    e.fullspan += arg.fullspan
    e.span = first(arg.span):last(e.span)
    unshift!(e.args, arg)
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
    if ps.errored
        return EXPR{ERROR}(Any[], ps.nt.startbyte - ps.t.startbyte, 1:(ps.t.endbyte - ps.t.startbyte + 1))
    elseif isidentifier(ps.t)
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
        return error_unexpected(ps, ps.t)
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

mutable struct UnaryOpCall
    op::OPERATOR
    arg
    fullspan::Int
    span::UnitRange{Int}
    function UnaryOpCall(op, arg)
        fullspan = op.fullspan + arg.fullspan
        new(op, arg, fullspan, 1:(fullspan - arg.fullspan + length(arg.span)))
    end
end
AbstractTrees.children(x::UnaryOpCall) = vcat(x.op, x.arg)

mutable struct UnarySyntaxOpCall
    arg1
    arg2
    fullspan::Int
    span::UnitRange{Int}
    function UnarySyntaxOpCall(arg1, arg2)
        fullspan = arg1.fullspan + arg2.fullspan
        new(arg1, arg2, fullspan, 1:(fullspan - arg2.fullspan + length(arg2.span)))
    end
end
AbstractTrees.children(x::UnarySyntaxOpCall) = vcat(x.arg1, x.arg2)

mutable struct BinaryOpCall
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
AbstractTrees.children(x::T) where T <: Union{BinaryOpCall} = vcat(x.arg1, x.op, x.arg2)

mutable struct BinarySyntaxOpCall
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
AbstractTrees.children(x::T) where T <: Union{BinarySyntaxOpCall} = vcat(x.arg1, x.op, x.arg2)

mutable struct WhereOpCall
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
AbstractTrees.children(x::T) where T <: Union{WhereOpCall} = vcat(x.arg1, x.op, x.args)

mutable struct ConditionalOpCall
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

AbstractTrees.children(x::ConditionalOpCall) = vcat(x.cond, x.op1, x.arg1, x.op2, x.arg2)

abstract type ComparisonOpCall <: Head end
abstract type ChainOpCall <: Head end
abstract type ColonOpCall <: Head end
abstract type Abstract <: Head end
abstract type Begin <: Head end
abstract type Bitstype <: Head end
abstract type Block <: Head end
abstract type Cell1d <: Head end
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
abstract type Parameters <: Head end
abstract type Primitive <: Head end
abstract type Quote <: Head end
abstract type Quotenode <: Head end
abstract type InvisBrackets <: Head end
abstract type StringH <: Head end
abstract type Struct <: Head end
abstract type Try <: Head end
abstract type TupleH <: Head end
abstract type TypeAlias <: Head end
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

Quotenode(x) = EXPR{Quotenode}(Any[x])

const TRUE = LITERAL(0, 1:0, "", Tokens.TRUE)
const FALSE = LITERAL(0, 1:0, "", Tokens.FALSE)
const NOTHING = LITERAL(0, 1:0, "", Tokens.NOTHING)

const GlobalRefDOC = EXPR{GlobalRefDoc}(Any[], 0, 1:0)
