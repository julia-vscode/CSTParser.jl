__precompile__()
module CSTParser
isdefined(Base, :GenericIOBuffer) ? (import Base.GenericIOBuffer) : (GenericIOBuffer{T} = Base.AbstractIOBuffer{T})
global debug = true

using AbstractTrees
using Tokenize
import Base: next, start, done, length, first, last, endof, getindex, setindex!
import Tokenize.Tokens
import Tokenize.Tokens: RawToken, AbstractToken, iskeyword, isliteral, isoperator, untokenize
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState, parse_expression

include("hints.jl")
import .Diagnostics: Diagnostic, LintCodes

include("lexer.jl")
include("spec.jl")
include("utils.jl")
include("components/lists.jl")
include("components/operators.jl")
include("components/controlflow.jl")
include("components/functions.jl")
include("components/genericblocks.jl")
include("components/loops.jl")
include("components/macros.jl")
include("components/modules.jl")
include("components/prefixkw.jl")
include("components/strings.jl")
include("components/types.jl")
include("conversion.jl")
include("display.jl")
include("scoping.jl")


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
    next(ps)
    
    if iskeyword(ps.t.kind) && ps.t.kind != Tokens.DO
        @catcherror ps ret = parse_kw(ps)
    elseif ps.t.kind == Tokens.LPAREN
        @catcherror ps ret = parse_paren(ps)
    elseif ps.t.kind == Tokens.LSQUARE
        @catcherror ps ret = parse_array(ps)
    elseif ps.t.kind == Tokens.LBRACE
        @catcherror ps ret = parse_cell1d(ps)
    elseif isinstance(ps.t) || isoperator(ps.t)
        if ps.t.kind == Tokens.WHERE
            ret = IDENTIFIER(ps)
        else
            ret = INSTANCE(ps)
        end
        if is_colon(ret) && ps.nt.kind != Tokens.COMMA
            @catcherror ps ret = parse_unary(ps, ret)
        end
    elseif ps.t.kind == Tokens.AT_SIGN
        @catcherror ps ret = parse_macrocall(ps)
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.t.kind in (Tokens.ENDMARKER, Tokens.COMMA, Tokens.RPAREN,
                         Tokens.RBRACE,Tokens.RSQUARE)
        return error_unexpected(ps, ps.t)
    elseif ps.t.kind == Tokens.ERROR
        return error_token(ps, ps.t)
    else
        ps.errored = true
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    end

    while !closer(ps)
        @catcherror ps ret = parse_compound(ps, ret)
    end

    return ret
end

function parse_kw(ps)
    k = ps.t.kind
    if k == Tokens.IF
        return parse_if(ps)
    elseif k == Tokens.LET
        return parse_let(ps)
    elseif k == Tokens.TRY
        return parse_try(ps)
    elseif k == Tokens.FUNCTION
        return parse_function(ps)
    elseif k == Tokens.BEGIN
        return parse_begin(ps)
    elseif k == Tokens.QUOTE
        return parse_quote(ps)
    elseif k == Tokens.FOR
        return parse_for(ps)
    elseif k == Tokens.WHILE
        return parse_while(ps)
    elseif k == Tokens.BREAK
        return INSTANCE(ps)
    elseif k == Tokens.CONTINUE
        return INSTANCE(ps)
    elseif k == Tokens.MACRO
        return parse_macro(ps)
    elseif k == Tokens.IMPORT
        return parse_imports(ps)
    elseif k == Tokens.IMPORTALL
        return parse_imports(ps)
    elseif k == Tokens.USING
        return parse_imports(ps)
    elseif k == Tokens.MODULE
        return parse_module(ps)
    elseif k == Tokens.BAREMODULE
        return parse_module(ps)
    elseif k == Tokens.EXPORT
        return parse_export(ps)
    elseif k == Tokens.CONST
        return parse_const(ps)
    elseif k == Tokens.GLOBAL
        return parse_global(ps)
    elseif k == Tokens.LOCAL
        return parse_local(ps)
    elseif k == Tokens.RETURN
        return parse_return(ps)
    elseif k == Tokens.END
        return parse_end(ps)
    elseif k == Tokens.ELSE || k == Tokens.ELSEIF || k == Tokens.CATCH || k == Tokens.FINALLY
        ret = IDENTIFIER(ps)
        ps.errored = true
        return EXPR{ERROR}(Any[])
    elseif k == Tokens.ABSTRACT
        return parse_abstract(ps)
    elseif k == Tokens.BITSTYPE
        return parse_bitstype(ps)
    elseif k == Tokens.PRIMITIVE
        return parse_primitive(ps)
    elseif k == Tokens.TYPEALIAS
        return parse_typealias(ps)
    elseif k == Tokens.TYPE
        return parse_struct(ps, true)
    elseif k == Tokens.IMMUTABLE || k == Tokens.STRUCT
        return parse_struct(ps, false)
    elseif k == Tokens.MUTABLE
        return parse_mutable(ps)
    end
end

"""
    parse_compound(ps, ret)

Handles cases where an expression - `ret` - is not followed by
`closer(ps) == true`. Possible juxtapositions are:
+ operators
+ `(`, calls
+ `[`, ref
+ `{`, curly
+ `,`, commas
+ `for`, generators
+ `do`
+ strings
+ an expression preceded by a unary operator
+ A number followed by an expression (with no seperating white space)
"""
function parse_compound(ps::ParseState, ret)
    if ps.nt.kind == Tokens.FOR
        ret = parse_generator(ps, ret)
    elseif ps.nt.kind == Tokens.DO
        ret = parse_do(ps, ret)
    elseif isajuxtaposition(ps, ret)
        op = OPERATOR(0, 1:0, Tokens.STAR, false)
        ret = parse_operator(ps, ret, op)
    elseif ps.nt.kind == Tokens.LPAREN && isemptyws(ps.ws)
        ret = @closer ps paren parse_call(ps, ret)
    elseif ps.nt.kind == Tokens.LBRACE && isemptyws(ps.ws)
        ret = parse_curly(ps, ret)
    elseif ps.nt.kind == Tokens.LSQUARE && isemptyws(ps.ws) && !(ret isa OPERATOR)
        ret = @nocloser ps block parse_ref(ps, ret)
    elseif ps.nt.kind == Tokens.COMMA
        ret = parse_tuple(ps, ret)
    elseif isunaryop(ret) && ps.nt.kind != Tokens.EQ
        ret = parse_unary(ps, ret)
    elseif isoperator(ps.nt)
        op = OPERATOR(next(ps))
        ret = parse_operator(ps, ret, op)
    elseif (ret isa IDENTIFIER || (ret isa BinarySyntaxOpCall && is_dot(ret.op))) && (ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING)
        next(ps)
        @catcherror ps arg = parse_string_or_cmd(ps, ret)
        ret = EXPR{x_Str}(Any[ret, arg])
    # Suffix on x_str
    elseif ret isa EXPR{x_Str} && ps.nt.kind == Tokens.IDENTIFIER
        arg = IDENTIFIER(next(ps))
        push!(ret, LITERAL(arg.fullspan, arg.span, val(ps.t, ps), Tokens.STRING))
    elseif (ret isa IDENTIFIER || (ret isa BinarySyntaxOpCall && is_dot(ret.op))) && ps.nt.kind == Tokens.CMD
        next(ps)
        @catcherror ps arg = parse_string_or_cmd(ps, ret)
        ret = EXPR{x_Cmd}(Any[ret, arg])
    elseif ret isa EXPR{x_Cmd} && ps.nt.kind == Tokens.IDENTIFIER
        arg = IDENTIFIER(next(ps))
        push!(ret, LITERAL(arg.fullspan, 1:span(arg), val(ps.t, ps), Tokens.STRING))
    elseif ret isa UnarySyntaxOpCall && is_prime(ret.arg2)
        # prime operator followed by an identifier has an implicit multiplication
        @catcherror ps nextarg = @precedence ps 11 parse_expression(ps)
        ret = BinaryOpCall(ret, OPERATOR(0, 1:0, Tokens.STAR,false), nextarg, Tokens.STAR, false)
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.nt.kind in (Tokens.ENDMARKER, Tokens.LPAREN, Tokens.RPAREN, Tokens.LBRACE,
                          Tokens.LSQUARE, Tokens.RSQUARE)
        return error_unexpected(ps, ps.nt)
    elseif ret isa OPERATOR
        ps.errored = true
        diag_range = ps.nt.startbyte - (ret.fullspan - length(ret.span) - first(ret.span) + 1) + ((-length(ret.span)):-1)
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedOperator}(
            # TODO: Which operator? How do we get at the spelling
            diag_range, [], "Unexpected operator"
        ))
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    elseif ps.nt.kind == Tokens.IDENTIFIER
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedIdentifier}(
            ps.nt.startbyte:ps.nt.endbyte, [], "Unexpected identifier"
        ))
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    elseif ps.nt.kind == Tokens.ERROR
        return error_token(ps, ps.nt)
    else
        ps.errored = true
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    end
    if ps.errored
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    end
    return ret
end

"""
    parse_paren(ps, ret)

Parses an expression starting with a `(`.
"""
function parse_paren(ps::ParseState)  
    args = Any[PUNCTUATION(ps)]
    @catcherror ps @default ps @nocloser ps inwhere @closer ps paren parse_comma_sep(ps, args, false, true, true)

    if ((length(args) == 2 && !(args[2] isa UnarySyntaxOpCall && is_dddot(args[2].arg2))) || (length(args) == 1 && args[1] isa EXPR{Block})) && ((ps.ws.kind != SemiColonWS || (length(args) == 2 && args[2] isa EXPR{Block})) && !(args[2] isa EXPR{Parameters}))
        push!(args, PUNCTUATION(next(ps)))
        ret = EXPR{InvisBrackets}(args)
    else
        push!(args, PUNCTUATION(next(ps)))
        ret = EXPR{TupleH}(args)
    end

    return ret
end

"""
    parse(str, cont = false)

Parses the passed string. If `cont` is true then will continue parsing until the end of the string returning the resulting expressions in a TOPLEVEL block.
"""
function parse(str::String, cont = false)
    ps = ParseState(str)
    x, ps = parse(ps, cont)
    if ps.errored
        x = EXPR{ERROR}(Any[])
    end
    return x
end

function parse_doc(ps::ParseState)
    if ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING
        doc = LITERAL(next(ps))
        if (ps.nt.kind == Tokens.ENDMARKER || ps.nt.kind == Tokens.END)
            return doc
        elseif isbinaryop(ps.nt) && !closer(ps)
            @catcherror ps ret = parse_compound(ps, doc)
            return ret
        end

        ret = parse_expression(ps)
        ret = EXPR{MacroCall}(Any[GlobalRefDOC, doc, ret])
    elseif ps.nt.kind == Tokens.IDENTIFIER && val(ps.nt, ps) == "doc" && (ps.nnt.kind == Tokens.STRING || ps.nnt.kind == Tokens.TRIPLE_STRING)
        doc = IDENTIFIER(next(ps))
        next(ps)
        @catcherror ps arg = parse_string_or_cmd(ps, doc)
        doc = EXPR{x_Str}(Any[doc, arg])
        ret = parse_expression(ps)
        ret = EXPR{MacroCall}(Any[GlobalRefDOC, doc, ret])
    else
        ret = parse_expression(ps)
    end
    return ret
end

function parse(ps::ParseState, cont = false)
    if ps.l.io.size == 0
        return (cont ? EXPR{FileH}(Any[]) : nothing), ps
    end
    last_line = 0
    curr_line = 0

    if cont
        top = EXPR{FileH}(Any[])
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            push!(top, LITERAL(ps.nt.startbyte, 1:ps.nt.startbyte, "", Tokens.NOTHING))
        end

        while !ps.done && !ps.errored
            curr_line = ps.nt.startpos[1]
            ret = parse_doc(ps)

            # join semicolon sep items
            if curr_line == last_line && last(top.args) isa EXPR{TopLevel}
                push!(last(top.args), ret)
            elseif ps.ws.kind == SemiColonWS
                push!(top, EXPR{TopLevel}(Any[ret]))
            else
                push!(top, ret)
            end
            last_line = curr_line
        end
    else
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            top = LITERAL(ps.nt.startbyte, 1:ps.nt.startbyte, "", Tokens.NOTHING)
        else
            top = parse_doc(ps)
            last_line = ps.nt.startpos[1]
            if ps.ws.kind == SemiColonWS
                top = EXPR{TopLevel}(Any[top])
                while ps.ws.kind == SemiColonWS && ps.nt.startpos[1] == last_line && ps.nt.kind != Tokens.ENDMARKER
                    ret = parse_doc(ps)
                    push!(top, ret)
                    last_line = ps.nt.startpos[1]
                end
            end
        end
    end

    return top, ps
end


function parse_file(path::String)
    x = parse(read(path, String), true)
    File([], [], path, x, [])
    # File([], (f -> (joinpath(dirname(path), f[1]), f[2])).(_get_includes(x)), path, x, [])
end

function parse_directory(path::String, proj = Project(path, []))
    for f in readdir(path)
        if isfile(joinpath(path, f)) && endswith(f, ".jl")
            try
                push!(proj.files, parse_file(joinpath(path, f)))
            catch
                println("$f failed to parse")
            end
        elseif isdir(joinpath(path, f))
            parse_directory(joinpath(path, f), proj)
        end
    end
    proj
end



ischainable(t::AbstractToken) = t.kind == Tokens.PLUS || t.kind == Tokens.STAR || t.kind == Tokens.APPROX

include("_precompile.jl")
_precompile_()
end
