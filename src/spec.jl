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

@enum(Head,IDENTIFIER,
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
ImportAll,
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
    InvalidIterator,
    StringInterpolationWithTrailingWhitespace,
    Unknown)

const NoKind = Tokenize.Tokens.begin_keywords

mutable struct Binding
    name::String
    val
    t
    refs::Vector
    overwrites::Union{Nothing,Binding}
end
function Binding(x)
    Binding(str_value(get_name(x)), x, nothing, [], nothing)
end


mutable struct Scope
    parent::Union{Nothing,Scope}
    names::Dict{String,Binding}
    modules::Union{Nothing,Dict{String,Any}}
    ismodule::Bool
end

Scope() = Scope(nothing, Dict{String,Binding}(), nothing, false)

mutable struct EXPR
    typ::Head
    args::Union{Nothing,Vector{EXPR}}
    fullspan::Int
    span::Int
    val::Union{Nothing,String}
    kind::Tokenize.Tokens.Kind
    dot::Bool
    parent::Union{Nothing,EXPR}
    scope::Union{Nothing,Scope}
    binding::Union{Nothing,Binding}
    ref
end

function EXPR(T::Head, args::Vector{EXPR}, fullspan::Int, span::Int)
    ex = EXPR(T, args, fullspan, span, nothing, NoKind, false, nothing, nothing, nothing, nothing)
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




@noinline mIDENTIFIER(ps::ParseState) = EXPR(IDENTIFIER, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), NoKind, false, nothing, nothing, nothing, nothing)

mPUNCTUATION(kind::Tokens.Kind, fullspan::Int, span::Int) = EXPR(PUNCTUATION, nothing, fullspan, span, nothing, kind, false, nothing, nothing, nothing, nothing)
@noinline mPUNCTUATION(ps::ParseState) = EXPR(PUNCTUATION, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, kindof(ps.t), false, nothing, nothing, nothing, nothing)

mOPERATOR(fullspan::Int, span::Int, kind::Tokens.Kind, dotop::Bool) = EXPR(OPERATOR, nothing, fullspan, span, nothing, kind, dotop, nothing, nothing, nothing, nothing)
@noinline mOPERATOR(ps::ParseState) = EXPR(OPERATOR, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, ps.t.suffix ? val(ps.t, ps) : nothing, kindof(ps.t), ps.t.dotop, nothing, nothing, nothing, nothing)

mKEYWORD(kind::Tokens.Kind, fullspan::Int, span::Int) = EXPR(KEYWORD, nothing, fullspan, span, nothing, kind, false, nothing, nothing, nothing, nothing)
@noinline mKEYWORD(ps::ParseState) = EXPR(KEYWORD, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, kindof(ps.t), false, nothing, nothing, nothing, nothing)

mLITERAL(fullspan::Int, span::Int, val::String, kind::Tokens.Kind) = EXPR(LITERAL, nothing, fullspan, span, val, kind, false, nothing, nothing, nothing, nothing)
@noinline function mLITERAL(ps::ParseState) 
    if kindof(ps.t) == Tokens.STRING || kindof(ps.t) == Tokens.TRIPLE_STRING ||
        kindof(ps.t) == Tokens.CMD || kindof(ps.t) == Tokens.TRIPLE_CMD
        return parse_string_or_cmd(ps)
    else
        mLITERAL(ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), kindof(ps.t))
    end
end



span(x::EXPR) = x.span

function update_span!(x::EXPR) end
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
    elseif kindof(ps.t) == Tokens.ERROR
        return EXPR(ErrorToken, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), NoKind, false, nothing, nothing, nothing, Unknown)
    else
        ps.errored = true
        return mErrorToken(Unknown)
    end
end


mutable struct File
    imports
    includes::Vector{Tuple{String,Any}}
    path::String
    ast::EXPR
    errors
end
File(path::String) = File([], [], path, EXPR(FileH, EXPR[]), [])

mutable struct Project
    path::String
    files::Vector{File}
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



mErrorToken(k::ErrorKind) = EXPR(ErrorToken, EXPR[], 0, 0, nothing, NoKind, false, nothing, nothing, nothing, k)
mErrorToken(x::EXPR, k) = EXPR(ErrorToken, EXPR[x], x.fullspan, x.span, nothing, NoKind, false, nothing, nothing, nothing, k)

TRUE() = mLITERAL(0, 0, "", Tokens.TRUE)
FALSE() = mLITERAL(0, 0, "", Tokens.FALSE)
NOTHING() = mLITERAL(0, 0, "", Tokens.NOTHING)
GlobalRefDOC() = EXPR(GlobalRefDoc, EXPR[])

typof(x::EXPR) = x.typ
valof(x::EXPR) = x.val
kindof(x::EXPR) = x.kind
kindof(t::Tokens.AbstractToken) = t.kind
parentof(x::EXPR) = x.parent
parentof(s::Scope) = s.parent
scopeof(x::EXPR) = x.scope
bindingof(x::EXPR) = x.binding
refof(x::EXPR) = x.ref

function setparent!(c, p)
    c.parent = p
    return c
end

function setscope!(x::EXPR, s = Scope())
    x.scope = s
    return x
end

function setref!(x::EXPR, r)
    x.ref = r
    return x
end


function setbinding!(x::EXPR)
    if typof(x) === TupleH
        for arg in x.args
            typof(arg) === PUNCTUATION && continue    
            setbinding!(arg)
        end
    elseif typof(x) === Kw
        setbinding!(x.args[1], x)
    elseif typof(x) === Parameters
        for arg in x.args
            typof(arg) === PUNCTUATION && continue    
            setbinding!(arg)
        end
    elseif typof(x) === InvisBrackets
        setbinding!(rem_invis(x))
    elseif typof(x) == UnaryOpCall && kindof(x.args[1]) === Tokens.DECLARATION
        return x
    else
        x.binding = Binding(x)
    end
    return x
end

function setbinding!(x::EXPR, binding)
    if typof(x) === TupleH
        for arg in x.args
            typof(arg) === PUNCTUATION && continue    
            setbinding!(arg, binding)
        end
    elseif typof(x) === InvisBrackets
        setbinding!(rem_invis(x), binding)
    elseif typof(x) === IDENTIFIER || (typof(x) === BinaryOpCall && kindof(x.args[2]) === Tokens.DECLARATION)
        x.binding = Binding(str_value(get_name(x)), binding, nothing, [], nothing)
    end
    return x
end



function setiterbinding!(iter::EXPR)
    if typof(iter) === BinaryOpCall && kindof(iter.args[2]) in (Tokens.EQ, Tokens.IN, Tokens.ELEMENT_OF)
        setbinding!(iter.args[1], iter)
    end
    return iter
end

function mark_sig_args!(x::EXPR)
    if typof(x) === Call || typof(x) === TupleH
        if typof(x.args[1]) === InvisBrackets && typof(x.args[1].args[2]) === BinaryOpCall && kindof(x.args[1].args[2].args[2]) === Tokens.DECLARATION
            setbinding!(x.args[1].args[2])
        end
        for i = 2:length(x.args) - 1
            a = x.args[i]
            if typof(a) === Parameters
                for j = 1:length(a.args)
                    aa = a.args[j]
                    if !(typof(aa) === PUNCTUATION)
                        setbinding!(aa)
                    end
                end
            elseif !(typof(a) === PUNCTUATION)
                setbinding!(a)
            end
        end
    elseif typof(x) === WhereOpCall
        for i in 3:length(x.args)
            if !(typof(x.args[i]) === PUNCTUATION)
                setbinding!(x.args[i])
            end
        end
        mark_sig_args!(x.args[1])
    elseif typof(x) === BinaryOpCall
        if kindof(x.args[2]) == Tokens.DECLARATION
            mark_sig_args!(x.args[1])
        else
            setbinding!(x.args[1])
            setbinding!(x.args[3])
        end
    elseif typof(x) == UnaryOpCall && typof(x.args[2]) == InvisBrackets
        setbinding!(x.args[2].args[2])
    end
end
Base.getindex(x::EXPR, i) = x.args[i]

function strip_where_scopes(sig::EXPR)
    if typof(sig) === WhereOpCall
        setscope!(sig, nothing)
        strip_where_scopes(sig.args[1])
    end
end

function mark_typealias_bindings!(x::EXPR)
    x.binding = Binding(str_value(get_name(x.args[1])), x, nothing, [], nothing)
    setscope!(x)
    for i = 2:length(x.args[1].args)
        if typof(x.args[1].args[i]) === IDENTIFIER
            setbinding!(x.args[1].args[i])
        elseif typof(x.args[1].args[i]) === BinaryOpCall && kindof(x.args[1].args[i].args[2]) === Tokens.ISSUBTYPE && typof(x.args[1].args[i].args[1]) === IDENTIFIER
            setbinding!(x.args[1].args[i].args[1])
        end
    end
    return x
end
