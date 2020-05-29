# Operator hierarchy
const AssignmentOp  = 1
const ConditionalOp = 2
const ArrowOp       = 3
const LazyOrOp      = 4
const LazyAndOp     = 5
const ComparisonOp  = 6
const PipeOp        = 7
const ColonOp       = 8
@static if Base.operator_precedence(:<<) == 12
    const PlusOp        = 9
    const BitShiftOp    = 10
    const TimesOp       = 11
    const RationalOp    = 12
else
    const PlusOp        = 9
    const TimesOp       = 10
    const RationalOp    = 11
    const BitShiftOp    = 12
end
const PowerOp       = 13
const DeclarationOp = 14
const WhereOp       = 15
const DotOp         = 16
const PrimeOp       = 16
const DddotOp       = 7
const AnonFuncOp    = 14

@enum(Head,IDENTIFIER,
NONSTDIDENTIFIER,
PUNCTUATION,
OPERATOR,
KEYWORD,
LITERAL,
NoHead,
Call,
UnaryOpCall,
BinaryOpCall,
WhereOpCall,
ConditionalOpCall,
ChainOpCall,
ColonOpCall,
Abstract,
Begin,
Block,
Braces,
BracesCat,
Const,
Comparison,
Curly,
Do,
Filter,
Flatten,
For,
FunctionDef,
Generator,
Global,
GlobalRefDoc,
If,
Kw,
Let,
Local,
Macro,
MacroCall,
MacroName,
Mutable,
Outer,
Parameters,
Primitive,
Quote,
Quotenode,
InvisBrackets,
StringH,
Struct,
Try,
TupleH,
FileH,
Return,
While,
x_Cmd,
x_Str,
ModuleH,
BareModule,
TopLevel,
Export,
Import,
Using,
Comprehension,
DictComprehension,
TypedComprehension,
Hcat,
TypedHcat,
Ref,
Row,
Vcat,
TypedVcat,
Vect,
ErrorToken)

@enum(ErrorKind,
    UnexpectedToken,
    CannotJuxtapose,
    UnexpectedWhiteSpace,
    UnexpectedNewLine,
    ExpectedAssignment,
    UnexpectedAssignmentOp,
    MissingConditional,
    MissingCloser,
    MissingColon, # We didn't get a colon (`:`) when we expected to while parsing a `?` expression.
    InvalidIterator,
    StringInterpolationWithTrailingWhitespace,
    TooLongChar,
    Unknown)

const NoKind = Tokenize.Tokens.begin_keywords

mutable struct EXPR
    typ::Head
    args::Union{Nothing,Vector{EXPR}}
    fullspan::Int
    span::Int
    val::Union{Nothing,String}
    kind::Tokenize.Tokens.Kind
    dot::Bool
    parent::Union{Nothing,EXPR}
    meta
end

function EXPR(T::Head, args::Vector{EXPR}, fullspan::Int, span::Int)
    ex = EXPR(T, args, fullspan, span, nothing, NoKind, false, nothing, nothing)
    for c in args
        setparent!(c, ex)
    end
    ex
end

function EXPR(T::Head, args::Vector{EXPR})
    ret = EXPR(T, args, 0, 0)
    update_span!(ret)
    ret
end




@noinline mIDENTIFIER(ps::ParseState) = EXPR(IDENTIFIER, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), NoKind, false, nothing, nothing)

mPUNCTUATION(kind::Tokens.Kind, fullspan::Int, span::Int) = EXPR(PUNCTUATION, nothing, fullspan, span, nothing, kind, false, nothing, nothing)
@noinline mPUNCTUATION(ps::ParseState) = EXPR(PUNCTUATION, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, kindof(ps.t), false, nothing, nothing)

mOPERATOR(fullspan::Int, span::Int, kind::Tokens.Kind, dotop::Bool) = EXPR(OPERATOR, nothing, fullspan, span, nothing, kind, dotop, nothing, nothing)
@noinline mOPERATOR(ps::ParseState) = EXPR(OPERATOR, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, ps.t.suffix ? val(ps.t, ps) : nothing, kindof(ps.t), ps.t.dotop, nothing, nothing)

mKEYWORD(kind::Tokens.Kind, fullspan::Int, span::Int) = EXPR(KEYWORD, nothing, fullspan, span, nothing, kind, false, nothing, nothing)
@noinline mKEYWORD(ps::ParseState) = EXPR(KEYWORD, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, kindof(ps.t), false, nothing, nothing)

mLITERAL(fullspan::Int, span::Int, val::String, kind::Tokens.Kind) = EXPR(LITERAL, nothing, fullspan, span, val, kind, false, nothing, nothing)
@noinline function mLITERAL(ps::ParseState)

    if kindof(ps.t) === Tokens.STRING || kindof(ps.t) === Tokens.TRIPLE_STRING ||
        kindof(ps.t) === Tokens.CMD || kindof(ps.t) === Tokens.TRIPLE_CMD
        return parse_string_or_cmd(ps)
    else
        v = val(ps.t, ps)
        if kindof(ps.t) === Tokens.CHAR && length(v) > 3 && !(v[2] == '\\' && valid_escaped_seq(v[2:prevind(v, length(v))]))
            return mErrorToken(ps, mLITERAL(ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, string(v[1:2], '\''), kindof(ps.t)), TooLongChar)
        end
        return mLITERAL(ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, v, kindof(ps.t))
    end
end



span(x::EXPR) = x.span

function update_span!(x::EXPR)
    (x.args isa Nothing || isempty(x.args)) && return
    x.fullspan = 0
    for i = 1:length(x.args)
        x.fullspan += x.args[i].fullspan
    end
    x.span = x.fullspan - last(x.args).fullspan + last(x.args).span
    return
end

function Base.push!(e::EXPR, arg::EXPR)
    e.span = e.fullspan + arg.span
    e.fullspan += arg.fullspan
    setparent!(arg, e)
    push!(e.args, arg)
end

function Base.pushfirst!(e::EXPR, arg::EXPR)
    e.fullspan += arg.fullspan
    setparent!(arg, e)
    pushfirst!(e.args, arg)
end

function Base.pop!(e::EXPR)
    arg = pop!(e.args)
    e.fullspan -= arg.fullspan
    if isempty(e.args)
        e.span = 0
    else
        e.span = e.fullspan - last(e.args).fullspan + last(e.args).span
    end
    arg
end

function Base.append!(e::EXPR, args::Vector{EXPR})
    append!(e.args, args)
    for arg in args
        setparent!(arg, e)
    end
    update_span!(e)
end

function Base.append!(a::EXPR, b::EXPR)
    append!(a.args, b.args)
    for arg in b.args
        setparent!(arg, a)
    end
    a.fullspan += b.fullspan
    a.span = a.fullspan + last(b.span)
end


function INSTANCE(ps::ParseState)
    if isidentifier(ps.t)
        return mIDENTIFIER(ps)
    elseif isliteral(ps.t)
        return mLITERAL(ps)
    elseif iskw(ps.t)
        return mKEYWORD(ps)
    elseif isoperator(ps.t)
        return mOPERATOR(ps)
    elseif ispunctuation(ps.t)
        return mPUNCTUATION(ps)
    elseif kindof(ps.t) === Tokens.ERROR
        ps.errored = true
        return EXPR(ErrorToken, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), NoKind, false, nothing, Unknown)
    else
        return mErrorToken(ps, Unknown)
    end
end

function mUnaryOpCall(op::EXPR, arg::EXPR)
    fullspan = op.fullspan + arg.fullspan
    ex = EXPR(UnaryOpCall, EXPR[op, arg], fullspan, fullspan - arg.fullspan + arg.span)
    setparent!(op, ex)
    setparent!(op, ex)
    return ex
end
function mBinaryOpCall(arg1::EXPR, op::EXPR, arg2::EXPR)
    fullspan = arg1.fullspan + op.fullspan + arg2.fullspan
    ex = EXPR(BinaryOpCall, EXPR[arg1, op, arg2], fullspan, fullspan - arg2.fullspan + arg2.span)
    setparent!(arg1, ex)
    setparent!(op, ex)
    setparent!(arg2, ex)
    return ex
end
function mWhereOpCall(arg1::EXPR, op::EXPR, args::Vector{EXPR})
    ex = EXPR(WhereOpCall, EXPR[arg1; op; args], arg1.fullspan + op.fullspan, 0)
    setparent!(arg1, ex)
    setparent!(op, ex)
    for a in args
        ex.fullspan += a.fullspan
        setparent!(a, ex)
    end
    ex.span = ex.fullspan - last(args).fullspan + last(args).span
    return ex
end

function mErrorToken(ps::ParseState, k::ErrorKind)
    ps.errored = true
    return EXPR(ErrorToken, EXPR[], 0, 0, nothing, NoKind, false, nothing, k)
end
function mErrorToken(ps::ParseState, x::EXPR, k)
    ps.errored = true
    ret = EXPR(ErrorToken, EXPR[x], x.fullspan, x.span, nothing, NoKind, false, nothing, k)
    setparent!(ret[1], ret)
    return ret
end

TRUE() = mLITERAL(0, 0, "", Tokens.TRUE)
FALSE() = mLITERAL(0, 0, "", Tokens.FALSE)
NOTHING() = mLITERAL(0, 0, "", Tokens.NOTHING)
GlobalRefDOC() = EXPR(GlobalRefDoc, EXPR[])

typof(x::EXPR) = x.typ
valof(x::EXPR) = x.val
kindof(x::EXPR) = x.kind
kindof(t::Tokens.AbstractToken) = t.kind
parentof(x::EXPR) = x.parent
errorof(x::EXPR) = errorof(x.meta)
errorof(x) = x

function setparent!(c, p)
    c.parent = p
    return c
end


Base.iterate(x::EXPR) = length(x) == 0 ? nothing : (x.args[1], 1)
Base.iterate(x::EXPR, s) = s < length(x) ? (x.args[s + 1], s + 1) : nothing
Base.length(x::EXPR) = x.args isa Nothing ? 0 : length(x.args)
Base.firstindex(x::EXPR) = 1
Base.lastindex(x::EXPR) = x.args === nothing ? 0 : lastindex(x.args)
Base.getindex(x::EXPR, i) = x.args[i]
Base.setindex!(x::EXPR, val, i) = Base.setindex!(x.args, val, i)
Base.first(x::EXPR) = x.args === nothing ? nothing : first(x.args)
Base.last(x::EXPR) = x.args === nothing ? nothing : last(x.args)
