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


abstract type LeafNode end
abstract type Head end
abstract type IDENTIFIER <: Head end
abstract type PUNCTUATION <: Head end
abstract type OPERATOR <: Head end
abstract type KEYWORD <: Head end
abstract type LITERAL <: Head end
abstract type NoHead <: Head end

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
    modules::Union{Nothing,Dict}
end

Scope() = Scope(nothing, Dict{String,Binding}(), nothing)

mutable struct EXPR
    typ::DataType
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

function EXPR(T::DataType, args::Vector{EXPR}, fullspan, span)
    ex = EXPR(T, args, fullspan, span, nothing, NoKind, false, nothing, nothing, nothing, nothing)
    for c in args
        setparent!(c, ex)
    end
    ex
end

function EXPR(T::DataType, args::Vector{EXPR})
    ret = EXPR(T, args, 0, 0)
    update_span!(ret)
    ret
end




@noinline IDENTIFIER(ps::ParseState) = EXPR(IDENTIFIER, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), NoKind, false, nothing, nothing, nothing, nothing)

PUNCTUATION(kind, fullspan, span) = EXPR(PUNCTUATION, nothing, fullspan, span, nothing, kind, false, nothing, nothing, nothing, nothing)
@noinline PUNCTUATION(ps::ParseState) = EXPR(PUNCTUATION, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, ps.t.kind, false, nothing, nothing, nothing, nothing)

OPERATOR(fullspan, span, kind, dotop) = EXPR(OPERATOR, nothing, fullspan, span, nothing, kind, dotop, nothing, nothing, nothing, nothing)
@noinline OPERATOR(ps::ParseState) = EXPR(OPERATOR, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, ps.t.kind, ps.t.dotop, nothing, nothing, nothing, nothing)

KEYWORD(kind, fullspan, span) = EXPR(KEYWORD, nothing, fullspan, span, nothing, kind, false, nothing, nothing, nothing, nothing)
@noinline KEYWORD(ps::ParseState) = EXPR(KEYWORD, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, nothing, ps.t.kind, false, nothing, nothing, nothing, nothing)

LITERAL(fullspan::Int, span::Int, val::String, kind) = EXPR(LITERAL, nothing, fullspan, span, val, kind, false, nothing, nothing, nothing, nothing)
@noinline function LITERAL(ps::ParseState) 
    if ps.t.kind == Tokens.STRING || ps.t.kind == Tokens.TRIPLE_STRING ||
        ps.t.kind == Tokens.CMD || ps.t.kind == Tokens.TRIPLE_CMD
         return parse_string_or_cmd(ps)
     else
         LITERAL(ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), ps.t.kind)
     end
end



span(x::EXPR) = x.span

function update_span!(x) end
function update_span!(x::EXPR)
    (x.args isa Nothing || isempty(x.args)) && return
    x.fullspan = 0
    for a in x.args
        x.fullspan += a.fullspan
    end
    x.span = x.fullspan - last(x.args).fullspan + last(x.args).span
    return 
end
    
function Base.push!(e::EXPR, arg)
    e.span = e.fullspan + arg.span
    e.fullspan += arg.fullspan
    setparent!(arg, e)
    push!(e.args, arg)
end

function Base.pushfirst!(e::EXPR, arg)
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

function Base.append!(e::EXPR, args::Vector)
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
File(path::String) = File([], [], path, EXPR(FileH, EXPR[]), [])

mutable struct Project
    path::String
    files::Vector{File}
end

abstract type Call <: Head end
abstract type UnaryOpCall <: Head end
abstract type BinaryOpCall <: Head end
abstract type WhereOpCall <: Head end
abstract type ConditionalOpCall <: Head end


function UnaryOpCall(op, arg) 
    fullspan = op.fullspan + arg.fullspan
    ex = EXPR(UnaryOpCall, EXPR[op, arg], fullspan, fullspan - arg.fullspan + arg.span)
    setparent!(op, ex)
    setparent!(op, ex)
    return ex
end
function BinaryOpCall(arg1, op, arg2) 
    fullspan = arg1.fullspan + op.fullspan + arg2.fullspan
    ex = EXPR(BinaryOpCall, EXPR[arg1, op, arg2], fullspan, fullspan - arg2.fullspan + arg2.span)
    setparent!(arg1, ex)
    setparent!(op, ex)
    setparent!(arg2, ex)
    return ex
end
function WhereOpCall(arg1, op, args)
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



abstract type ChainOpCall <: Head end
abstract type ColonOpCall <: Head end
abstract type Abstract <: Head end
abstract type Begin <: Head end
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
ErrorToken() = EXPR(ErrorToken, EXPR[])
ErrorToken(x) = EXPR(ErrorToken, EXPR[x])

TRUE() = LITERAL(0, 0, "", Tokens.TRUE)
FALSE() = LITERAL(0, 0, "", Tokens.FALSE)
NOTHING() = LITERAL(0, 0, "", Tokens.NOTHING)
GlobalRefDOC() = EXPR(GlobalRefDoc, EXPR[])

function setparent!(c, p)
    c.parent = p
    return c
end

function newscope!(x)
    x.scope = Scope()
    return x
end


function setbinding!(x)
    if x.typ === TupleH
        for arg in x.args
            arg.typ === PUNCTUATION && continue    
            setbinding!(arg)
        end
    elseif x.typ === Kw
        setbinding!(x.args[1], x)
    elseif x.typ === InvisBrackets
        setbinding!(rem_invis(x))
    else
        x.binding = Binding(x)
    end
    return x
end

function setbinding!(x, binding)
    if x.typ === TupleH
        for arg in x.args
            arg.typ === PUNCTUATION && continue    
            setbinding!(arg, binding)
        end
    elseif x.typ === InvisBrackets
        setbinding!(rem_invis(x), binding)
    else
        x.binding = Binding(str_value(get_name(x)), binding, nothing, [], nothing)
    end
    return x
end



function setiterbinding!(iter)
    if iter.typ === BinaryOpCall && iter.args[2].kind in (Tokens.EQ, Tokens.IN, Tokens.ELEMENT_OF)
        setbinding!(iter.args[1], iter)
    end
    return iter
end

function mark_sig_args!(x)
    if x.typ === Call
        for i = 3:length(x.args)-1
            a = x.args[i]
            if a.typ === Parameters
                for j = 1:length(a.args)
                    aa = a.args[j]
                    if !(aa.typ === PUNCTUATION)
                        setbinding!(aa)
                    end
                end
            elseif !(a.typ === PUNCTUATION)
                setbinding!(a)
            end
        end
    elseif x.typ === WhereOpCall
        for i in 3:length(x.args)
            if !(x.args[i].typ === PUNCTUATION)
                setbinding!(x.args[i])
            end
        end
        mark_sig_args!(x.args[1])
    elseif x.typ === BinaryOpCall && x.args[2].kind == Tokens.DECLARATION
        mark_sig_args!(x.args[1])
    end
end
Base.getindex(x::EXPR, i) = x.args[i]

function strip_where_scopes(sig)
    if sig.typ === WhereOpCall
        sig.scope = nothing
        strip_where_scopes(sig.args[1])
    end
end