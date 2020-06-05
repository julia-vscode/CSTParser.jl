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

"""
Expression types. All-caps indicates a terminal node.
"""
# Terminals
    :Identifier,
    :NonStdIdentifier,
    :Operator
    # Punctuation
        :Comma,
        :LParen,
        :RParen,
        :LSquare,
        :RSquare,
        :LBrace,
        :RBrace,
        :AtSign,
        :Dot,
        
    # Keywords
        :ABSTRACT,
        :baremodule,
        :begin,
        :break,
        :catch,
        :const,
        :continue,
        :do,
        :else,
        :elseif,
        :end,
        :export,
        :finally,
        :for,
        :function,
        :global,
        :if,
        :import,
        :importall,
        :let,
        :local,
        :macro,
        :module,
        :mutable,
        :new,
        :outer,
        :primitive,
        :quote,
        :return,
        :struct,
        :try,
        :type,
        :using,
        :while,

    # Literals
        :integer,
        :bin_int,
        :hexint,
        :octint,
        :float,
        :string,
        :triplestring,
        :char,
        :cmd,
        :triplecmd,
        :nothing,
        :true,
        :false,

# Expressions
:Call,
:ChainOpCall,
:ColonOpCall,
:Abstract,
:Begin,
:Block,
:Braces,
:BracesCat,
:Const,
:Comparison,
:Curly,
:Do,
:Filter,
:Flatten,
:For,
:Function,
:Generator,
:Global,
:GlobalRefDoc,
:If,
:Kw,
:Let,
:Local,
:Macro,
:MacroCall,
:MacroName,
:Mutable,
:Outer,
:Parameters,
:Primitive,
:Quote,
:Quotenode,
:Brackets,
:String,
:Struct,
:Try,
:Tuple,
:File,
:Return,
:While,
:x_Cmd,
:x_Str,
:Module,
:BareModule,
:TopLevel,
:Export,
:Import,
:Using,
:Comprehension,
:Dict_Comprehension,
:Typed_Comprehension,
:Hcat,
:Typed_Hcat,
:Ref,
:Row,
:Vcat,
:Typed_Vcat,
:Vect,
:ErrorToken

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
    head::Union{Symbol,EXPR}
    args::Union{Nothing,Vector{EXPR}}
    trivia::Union{Nothing,Vector{EXPR}}
    fullspan::Int
    span::Int
    val::Union{Nothing,String}
    parent::Union{Nothing,EXPR}
    meta
end

function EXPR(head::Union{Symbol,EXPR}, args::Vector{EXPR}, trivia::Union{Vector{EXPR},Nothing}, fullspan::Int, span::Int)
    ex = EXPR(head, args, trivia, fullspan, span, nothing, nothing, nothing)
    for c in args
        setparent!(c, ex)
    end
    if trivia isa Vector{EXPR}
        for c in trivia
            setparent!(c, ex)
        end
    end
    ex
end

function EXPR(head::Union{Symbol,EXPR}, args::Vector{EXPR}, trivia::Union{Vector{EXPR},Nothing} = EXPR[])
    ret = EXPR(head, args, trivia, 0, 0)
    update_span!(ret)
    ret
end

# These methods are for terminal/childless expressions.
@noinline EXPR(head::Union{Symbol,EXPR}, fullspan::Int, span::Int, val = nothing) = EXPR(head, nothing, nothing, fullspan, span, val, nothing, nothing)
@noinline EXPR(head::Union{Symbol,EXPR}, ps::ParseState) = EXPR(head, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps))
@noinline EXPR(ps::ParseState) = EXPR(tokenkindtoheadmap(kindof(ps.t)), ps)

@noinline function mLITERAL(ps::ParseState)
    if kindof(ps.t) === Tokens.STRING || kindof(ps.t) === Tokens.TRIPLE_STRING ||
        kindof(ps.t) === Tokens.CMD || kindof(ps.t) === Tokens.TRIPLE_CMD
        return parse_string_or_cmd(ps)
    else
        v = val(ps.t, ps)
        if kindof(ps.t) === Tokens.CHAR && length(v) > 3 && !(v[2] == '\\' && valid_escaped_seq(v[2:prevind(v, length(v))]))
            return mErrorToken(ps, EXPR(:char, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, string(v[1:2], '\'')), TooLongChar)
        end
        return EXPR(literalmap(kindof(ps.t)), ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, v)
    end
end



span(x::EXPR) = x.span

function update_span!(x::EXPR)
    (x.args isa Nothing || isempty(x.args)) && !hastrivia(x) && return
    x.fullspan = 0
    for i = 1:length(x.args)
        x.fullspan += x.args[i].fullspan
    end
    if hastrivia(x)
        for i = 1:length(x.trivia)
            x.fullspan += x.trivia[i].fullspan
        end
    end
    if x.head isa EXPR
        x.fullspan += x.head.fullspan
        # TODO: special case for trailing unary ops?
    end
    if x.head isa EXPR && isoperator(x.head) && (is_dddot(x.head) || is_prime(x.head))
        # trailing unary operator
        x.span  = x.fullspan - x.head.fullspan + x.head.span
    elseif lastchildistrivia(x)
        x.span = x.fullspan - last(x.trivia).fullspan + last(x.trivia).span
    elseif !isempty(x.args)
        x.span = x.fullspan - last(x.args).fullspan + last(x.args).span
    end
    return
end

function Base.push!(e::EXPR, arg::EXPR)
    e.span = e.fullspan + arg.span
    e.fullspan += arg.fullspan
    setparent!(arg, e)
    push!(e.args, arg)
end

function pushtotrivia!(e::EXPR, arg::EXPR)
    e.span = e.fullspan + arg.span
    e.fullspan += arg.fullspan
    setparent!(arg, e)
    push!(e.trivia, arg)
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
        return EXPR(:Identifier, ps)
    elseif isliteral(ps.t)
        return mLITERAL(ps)
    elseif iskeyword(ps.t)
        return EXPR(ps)
    elseif isoperator(ps.t)
        return EXPR(:Operator, ps)
    elseif ispunctuation(ps.t)
        return EXPR(ps)
    elseif kindof(ps.t) === Tokens.ERROR
        ps.errored = true
        return EXPR(:ErrorToken, nothing, nothing, ps.nt.startbyte - ps.t.startbyte, ps.t.endbyte - ps.t.startbyte + 1, val(ps.t, ps), nothing, Unknown)
    else
        return mErrorToken(ps, Unknown)
    end
end

function mUnaryOpCall(op::EXPR, arg::EXPR)
    fullspan = op.fullspan + arg.fullspan
    ex = EXPR(:Call, EXPR[op, arg], nothing, fullspan, fullspan - arg.fullspan + arg.span)
    setparent!(op, ex)
    setparent!(op, ex)
    return ex
end

function mWhereOpCall(arg1::EXPR, op::EXPR, args::Vector{EXPR})
    ex = EXPR(:Call, EXPR[arg1; op; args], nothing,  arg1.fullspan + op.fullspan, 0)
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
    return EXPR(:ErrorToken, EXPR[], nothing, 0, 0, nothing, nothing, k)
end
function mErrorToken(ps::ParseState, x::EXPR, k)
    ps.errored = true
    ret = EXPR(:ErrorToken, EXPR[x], nothing, x.fullspan, x.span, nothing, nothing, k)
    setparent!(ret.args[1], ret)
    return ret
end


headof(x::EXPR) = x.head
valof(x::EXPR) = x.val
kindof(t::Tokens.AbstractToken) = t.kind
parentof(x::EXPR) = x.parent
errorof(x::EXPR) = errorof(x.meta)
errorof(x) = x

function setparent!(c, p)
    c.parent = p
    return c
end
hastrivia(x::EXPR) = x.trivia !== nothing && length(x.trivia) > 0

function lastchildistrivia(x::EXPR)
    return hastrivia(x) && (last(x.trivia).head in (:end, :RParen, :RSquare, :RBrace) || (x.head in (:Parameters, :Tuple) && length(x.args) <= length(x.trivia)))
end

function Base.length(x::EXPR) 
    n = x.args isa Nothing ? 0 : length(x.args)
    n += hastrivia(x) ? length(x.trivia) : 0
    x.head isa EXPR && (n += 1)
    return n
end

function keywordmap(k::Tokens.Kind)
    if k === Tokens.ABSTRACT
        return :abstract
    elseif k === Tokens.BAREMODULE
        return :baremodule
    elseif k === Tokens.BEGIN
        return :begin
    elseif k === Tokens.BREAK
        return :break
    elseif k === Tokens.CATCH
        return :catch
    elseif k === Tokens.CONST
        return :const
    elseif k === Tokens.CONTINUE
        return :continue
    elseif k === Tokens.DO
        return :do
    elseif k === Tokens.ELSE
        return :else
    elseif k === Tokens.ELSEIF
        return :elseif
    elseif k === Tokens.END
        return :end
    elseif k === Tokens.EXPORT
        return :export
    elseif k === Tokens.FINALLY
        return :finally
    elseif k === Tokens.FOR
        return :for
    elseif k === Tokens.FUNCTION
        return :function
    elseif k === Tokens.GLOBAL
        return :global
    elseif k === Tokens.IF
        return :if
    elseif k === Tokens.IMPORT
        return :import
    elseif k === Tokens.IMPORTALL
        return :importall
    elseif k === Tokens.LET
        return :let
    elseif k === Tokens.LOCAL
        return :local
    elseif k === Tokens.MACRO
        return :macro
    elseif k === Tokens.MODULE
        return :module
    elseif k === Tokens.MUTABLE
        return :mutable
    elseif k === Tokens.NEW
        return :new
    elseif k === Tokens.OUTER
        return :outer
    elseif k === Tokens.PRIMITIVE
        return :primitive
    elseif k === Tokens.QUOTE
        return :quote
    elseif k === Tokens.RETURN
        return :return
    elseif k === Tokens.STRUCT
        return :struct
    elseif k === Tokens.TRY
        return :try
    elseif k === Tokens.TYPE
        return :type
    elseif k === Tokens.USING
        return :using
    elseif k === Tokens.WHILE
        return :while
    end
end

function literalmap(k::Tokens.Kind)
    if k === Tokens.INTEGER
        return :integer
    elseif k === Tokens.BIN_INT
        return :bin_int
    elseif k === Tokens.HEX_INT
        return :hexint
    elseif k === Tokens.OCT_INT
        return :octint
    elseif k === Tokens.FLOAT
        return :float
    elseif k === Tokens.STRING
        return :string
    elseif k === Tokens.TRIPLE_STRING
        return :triplestring
    elseif k === Tokens.CHAR
        return :char
    elseif k === Tokens.CMD
        return :cmd
    elseif k === Tokens.TRIPLE_CMD
        return :triplecmd
    elseif k === Tokens.TRUE
        return :(var"true")
    elseif k === Tokens.FALSE
        return :(var"false")
    end
end

function punctuationmap(k::Tokens.Kind)
    if k == Tokens.COMMA
        :Comma
    elseif k == Tokens.LPAREN
        :LParen
    elseif k == Tokens.RPAREN
        :RParen
    elseif k == Tokens.LSQUARE
        :LSquare
    elseif k == Tokens.RSQUARE
        :RSquare
    elseif k == Tokens.LBRACE
        :LBrace
    elseif k == Tokens.RBRACE
        :RBrace
    elseif k == Tokens.AT_SIGN
        :AtSign
    elseif k == Tokens.DOT
        :Dot
    end
end

function tokenkindtoheadmap(k::Tokens.Kind)
    if k == Tokens.COMMA
        :Comma
    elseif k == Tokens.LPAREN
        :LParen
    elseif k == Tokens.RPAREN
        :RParen
    elseif k == Tokens.LSQUARE
        :LSquare
    elseif k == Tokens.RSQUARE
        :RSquare
    elseif k == Tokens.LBRACE
        :LBrace
    elseif k == Tokens.RBRACE
        :RBrace
    elseif k == Tokens.AT_SIGN
        :AtSign
    elseif k == Tokens.DOT
        :Dot
    elseif k === Tokens.ABSTRACT
        return :abstract
    elseif k === Tokens.BAREMODULE
        return :baremodule
    elseif k === Tokens.BEGIN
        return :begin
    elseif k === Tokens.BREAK
        return :break
    elseif k === Tokens.CATCH
        return :catch
    elseif k === Tokens.CONST
        return :const
    elseif k === Tokens.CONTINUE
        return :continue
    elseif k === Tokens.DO
        return :do
    elseif k === Tokens.ELSE
        return :else
    elseif k === Tokens.ELSEIF
        return :elseif
    elseif k === Tokens.END
        return :end
    elseif k === Tokens.EXPORT
        return :export
    elseif k === Tokens.FINALLY
        return :finally
    elseif k === Tokens.FOR
        return :for
    elseif k === Tokens.FUNCTION
        return :function
    elseif k === Tokens.GLOBAL
        return :global
    elseif k === Tokens.IF
        return :if
    elseif k === Tokens.IMPORT
        return :import
    elseif k === Tokens.IMPORTALL
        return :importall
    elseif k === Tokens.LET
        return :let
    elseif k === Tokens.LOCAL
        return :local
    elseif k === Tokens.MACRO
        return :macro
    elseif k === Tokens.MODULE
        return :module
    elseif k === Tokens.MUTABLE
        return :mutable
    elseif k === Tokens.NEW
        return :new
    elseif k === Tokens.OUTER
        return :outer
    elseif k === Tokens.PRIMITIVE
        return :primitive
    elseif k === Tokens.QUOTE
        return :quote
    elseif k === Tokens.RETURN
        return :return
    elseif k === Tokens.STRUCT
        return :struct
    elseif k === Tokens.TRY
        return :try
    elseif k === Tokens.TYPE
        return :type
    elseif k === Tokens.USING
        return :using
    elseif k === Tokens.WHILE
        return :while
    elseif k === Tokens.INTEGER
        return :integer
    elseif k === Tokens.BIN_INT
        return :bin_int
    elseif k === Tokens.HEX_INT
        return :hexint
    elseif k === Tokens.OCT_INT
        return :octint
    elseif k === Tokens.FLOAT
        return :float
    elseif k === Tokens.STRING
        return :string
    elseif k === Tokens.TRIPLE_STRING
        return :triplestring
    elseif k === Tokens.CHAR
        return :char
    elseif k === Tokens.CMD
        return :cmd
    elseif k === Tokens.TRIPLE_CMD
        return :triplecmd
    elseif k === Tokens.TRUE
        return :(var"true")
    elseif k === Tokens.FALSE
        return :(var"false")
    end
end
