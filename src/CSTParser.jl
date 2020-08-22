module CSTParser
global debug = true

using Tokenize
import Base: length, first, last, getindex, setindex!
import Tokenize.Tokens
import Tokenize.Tokens: RawToken, AbstractToken, iskeyword, isliteral, isoperator, untokenize
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState, parse_expression

include("lexer.jl")
include("spec.jl")
include("utils.jl")
include("recovery.jl")
include("components/internals.jl")
include("components/keywords.jl")
include("components/lists.jl")
include("components/operators.jl")
include("components/strings.jl")
include("conversion.jl")
include("display.jl")
include("interface.jl")

"""
    parse_expression(ps)

Parses an expression until `closer(ps) == true`. Expects to enter the
`ParseState` the token before the the beginning of the expression and ends
on the last token.

Acceptable starting tokens are:
+ A keyword
+ An opening parentheses or brace.
+ An operator.
+ An instance (e.g. identifier, number, etc.)
+ An `@`.

"""
function parse_expression(ps::ParseState)
    if kindof(ps.nt) ∈ term_c && !(kindof(ps.nt) === Tokens.END && ps.closer.square)
        ret = mErrorToken(ps, INSTANCE(next(ps)), UnexpectedToken)
    else
        next(ps)
        if iskeyword(kindof(ps.t)) && kindof(ps.t) != Tokens.DO
            ret = parse_kw(ps)
        elseif kindof(ps.t) === Tokens.LPAREN
            ret = parse_paren(ps)
        elseif kindof(ps.t) === Tokens.LSQUARE
            ret = @default ps parse_array(ps)
        elseif kindof(ps.t) === Tokens.LBRACE
            ret = @default ps @closebrace ps parse_braces(ps)
        elseif isinstance(ps.t) || isoperator(ps.t)
            if both_symbol_and_op(ps.t)
                ret = mIDENTIFIER(ps)
            else
                ret = INSTANCE(ps)
            end
            if is_colon(ret) && !(iscomma(ps.nt) || kindof(ps.ws) == SemiColonWS)
                ret = parse_unary(ps, ret)
            elseif isoperator(ret) && precedence(ret) == AssignmentOp && kindof(ret) !== Tokens.APPROX
                ret = mErrorToken(ps, ret, UnexpectedAssignmentOp)
            end
        elseif kindof(ps.t) === Tokens.AT_SIGN
            ret = parse_macrocall(ps)
        else
            ret = mErrorToken(ps, INSTANCE(ps), UnexpectedToken)
        end
        ret = parse_compound_recur(ps, ret)
    end
    return ret
end

parse_compound_recur(ps, ret) = !closer(ps) ? parse_compound_recur(ps, parse_compound(ps, ret)) : ret

"""
    parse_compound(ps::ParseState, ret::EXPR)

Attempts to parse a compound expression given the preceding expression `ret`.
"""
function parse_compound(ps::ParseState, ret::EXPR)
    if kindof(ps.nt) === Tokens.FOR
        ret = parse_generator(ps, ret)
    elseif kindof(ps.nt) === Tokens.DO
        ret = @default ps @closer ps :block parse_do(ps, ret)
    elseif isajuxtaposition(ps, ret)
        if disallowednumberjuxt(ret)
            ret = mErrorToken(ps, ret, CannotJuxtapose)
        end
        op = mOPERATOR(0, 0, Tokens.STAR, false)
        ret = parse_operator(ps, ret, op)
    elseif (typof(ret) === x_Str || typof(ret) === x_Cmd) && isidentifier(ps.nt)
        arg = mIDENTIFIER(next(ps))
        push!(ret, mLITERAL(arg.fullspan, arg.span, val(ps.t, ps), Tokens.STRING))
    elseif (isidentifier(ret) || is_getfield(ret)) && isemptyws(ps.ws) && isprefixableliteral(ps.nt)
        next(ps)
        arg = parse_string_or_cmd(ps, ret)
        if kindof(arg) === Tokens.CMD || kindof(arg) === Tokens.TRIPLE_CMD
            ret = EXPR(x_Cmd, EXPR[ret, arg])
        elseif valof(ret) == "var" && VERSION > v"1.3.0-"
            ret = EXPR(NONSTDIDENTIFIER, EXPR[ret, arg])
        else
            ret = EXPR(x_Str, EXPR[ret, arg])
        end
    elseif kindof(ps.nt) === Tokens.LPAREN
        no_ws = !isemptyws(ps.ws)
        ret = @closeparen ps parse_call(ps, ret)
        if no_ws && !isunarycall(ret)
            ret = mErrorToken(ps, ret, UnexpectedWhiteSpace)
        end
    elseif kindof(ps.nt) === Tokens.LBRACE
        if isemptyws(ps.ws)
            ret = @default ps @nocloser ps :inwhere @closebrace ps parse_curly(ps, ret)
        else
            ret = mErrorToken(ps, (@default ps @nocloser ps :inwhere @closebrace ps parse_curly(ps, ret)), UnexpectedWhiteSpace)
        end
    elseif kindof(ps.nt) === Tokens.LSQUARE && isemptyws(ps.ws) && !isoperator(ret)
        ret = @default ps @nocloser ps :block parse_ref(ps, ret)
    elseif iscomma(ps.nt)
        ret = parse_tuple(ps, ret)
    elseif isunaryop(ret) && kindof(ps.nt) != Tokens.EQ
        ret = parse_unary(ps, ret)
    elseif isoperator(ps.nt)
        op = mOPERATOR(next(ps))
        ret = parse_operator(ps, ret, op)
    elseif isunarycall(ret) && is_prime(ret.args[2])
        # prime operator followed by an identifier has an implicit multiplication
        nextarg = @precedence ps TimesOp parse_expression(ps)
        ret = mBinaryOpCall(ret, mOPERATOR(0, 0, Tokens.STAR, false), nextarg)
# ###############################################################################
# Everything below here is an error
# ###############################################################################
    else
        ps.errored = true
        if kindof(ps.nt) in (Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE)
            nextarg = mErrorToken(ps, mPUNCTUATION(next(ps)), Unknown)
        else
            nextarg = parse_expression(ps)
        end
        ret = EXPR(ErrorToken, EXPR[ret, nextarg])
    end
    return ret
end

"""
    parse_paren(ps, ret)

Parses an expression starting with a `(`.
"""
function parse_paren(ps::ParseState)
    args = EXPR[mPUNCTUATION(ps)]
    @closeparen ps @default ps @nocloser ps :inwhere parse_comma_sep(ps, args, false, true, true)

    if length(args) == 2 && ((kindof(ps.ws) !== SemiColonWS || typof(args[2]) === Block) && typof(args[2]) !== Parameters)
        accept_rparen(ps, args)
        ret = EXPR(InvisBrackets, args)
    else
        accept_rparen(ps, args)
        ret = EXPR(TupleH, args)
    end
    return ret
end

"""
    parse(str, cont = false)

Parses the passed string. If `cont` is true then will continue parsing until the end of the string returning the resulting expressions in a TOPLEVEL block.
"""
function parse(str::String, cont=false)
    ps = ParseState(str)
    x, ps = parse(ps, cont)
    return x
end

"""
    parse_doc(ps::ParseState)

Used for top-level parsing - attaches documentation (such as this) to expressions.
"""
function parse_doc(ps::ParseState)
    if (kindof(ps.nt) === Tokens.STRING || kindof(ps.nt) === Tokens.TRIPLE_STRING) && !isemptyws(ps.nws)
        doc = mLITERAL(next(ps))
        if kindof(ps.nt) === Tokens.ENDMARKER || kindof(ps.nt) === Tokens.END || ps.t.endpos[1] + 1 < ps.nt.startpos[1]
            return doc
        elseif isbinaryop(ps.nt) && !closer(ps)
            ret = parse_compound(ps, doc)
            return ret
        end

        ret = parse_expression(ps)
        ret = EXPR(MacroCall, EXPR[GlobalRefDOC(), doc, ret])
    elseif nexttokenstartsdocstring(ps)
        doc = mIDENTIFIER(next(ps))
        arg = parse_string_or_cmd(next(ps), doc)
        doc = EXPR(x_Str, EXPR[doc, arg])
        ret = parse_expression(ps)
        ret = EXPR(MacroCall, EXPR[GlobalRefDOC(), doc, ret])
    else
        ret = parse_expression(ps)
    end
    return ret
end

function parse(ps::ParseState, cont=false)
    if ps.l.io.size == 0
        return (cont ? EXPR(FileH, EXPR[]) : nothing), ps
    end
    last_line = 0
    curr_line = 0

    if cont
        top = EXPR(FileH, EXPR[])
        if kindof(ps.nt) === Tokens.WHITESPACE || kindof(ps.nt) === Tokens.COMMENT
            next(ps)
            push!(top, mLITERAL(ps.nt.startbyte, ps.nt.startbyte, "", Tokens.NOTHING))
        end

        safetytrip = 0
        while kindof(ps.nt) !== Tokens.ENDMARKER
            safetytrip += 1
            if safetytrip > 10_000
                throw(CSTInfiniteLoop("Infinite loop at $ps"))
            end
            curr_line = ps.nt.startpos[1]
            ret = parse_doc(ps)
            if _continue_doc_parse(ps, ret)
                push!(ret, parse_expression(ps))
            end
            # join semicolon sep items
            if curr_line == last_line && typof(last(top.args)) === TopLevel
                push!(last(top.args), ret)
                top.fullspan += ret.fullspan
                top.span = top.fullspan - (ret.fullspan - ret.span)
            elseif kindof(ps.ws) == SemiColonWS
                push!(top, EXPR(TopLevel, EXPR[ret]))
            else
                push!(top, ret)
            end
            last_line = curr_line
        end
    else
        if kindof(ps.nt) === Tokens.WHITESPACE || kindof(ps.nt) === Tokens.COMMENT
            next(ps)
            top = mLITERAL(ps.nt.startbyte, ps.nt.startbyte, "", Tokens.NOTHING)
        elseif !(ps.done || kindof(ps.nt) === Tokens.ENDMARKER)
            curr_line = ps.nt.startpos[1]
            top = parse_doc(ps)
            if _continue_doc_parse(ps, top)
                push!(top, parse_expression(ps))
            end
            last_line = ps.nt.startpos[1]
            if kindof(ps.ws) == SemiColonWS
                top = EXPR(TopLevel, EXPR[top])
                safetytrip = 0
                while kindof(ps.ws) == SemiColonWS && ps.nt.startpos[1] == last_line && kindof(ps.nt) != Tokens.ENDMARKER
                    safetytrip += 1
                    if safetytrip > 10_000
                        throw(CSTInfiniteLoop("Infinite loop at $ps"))
                    end
                    ret = parse_doc(ps)
                    push!(top, ret)
                    last_line = ps.nt.startpos[1]
                end
            end
        else
            top = EXPR(ErrorToken, EXPR[], 0, 0)
        end
    end

    return top, ps
end

function _continue_doc_parse(ps::ParseState, x::EXPR)
    typof(x) === MacroCall &&
    typof(x.args[1]) === MacroName &&
    length(x.args[1]) == 2 &&
    valof(x.args[1].args[2]) == "doc" &&
    length(x.args) < 3 &&
    ps.t.endpos[1] + 1 <= ps.nt.startpos[1]
end

include("precompile.jl")
_precompile()
end
