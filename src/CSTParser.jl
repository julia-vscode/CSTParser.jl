__precompile__()
module CSTParser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last, endof, getindex, setindex!
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState, parse_expression

include("hints.jl")
import .Diagnostics: Diagnostic, LintCodes, FormatCodes

include("lexer.jl")
include("errors.jl")
include("spec.jl")
include("utils.jl")
# include("iterators.jl")
# include("scoping.jl")
include("deprecations.jl")
include("components/array.jl")
include("components/curly.jl")
include("components/operators.jl")
include("components/do.jl")
include("components/functions.jl")
include("components/genericblocks.jl")
include("components/if.jl")
include("components/let.jl")
include("components/loops.jl")
include("components/generators.jl")
include("components/macros.jl")
include("components/modules.jl")
include("components/prefixkw.jl")
include("components/quote.jl")
include("components/strings.jl")
include("components/try.jl")
include("components/types.jl")
include("components/tuples.jl")
include("conversion.jl")
include("display.jl")


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
    startbyte = ps.nt.startbyte
    next(ps)
    if Tokens.begin_keywords < ps.t.kind < Tokens.end_keywords && ps.t.kind != Tokens.DO
        @catcherror ps startbyte ret = parse_kw(ps, Val{ps.t.kind})
    elseif ps.t.kind == Tokens.LPAREN
        @catcherror ps startbyte ret = parse_paren(ps)
    elseif ps.t.kind == Tokens.LSQUARE
        @catcherror ps startbyte ret = parse_array(ps)
    elseif ps.t.kind == Tokens.LBRACE
        @catcherror ps startbyte ret = parse_cell1d(ps)
    elseif isinstance(ps.t) || isoperator(ps.t)
        if ps.t.kind == Tokens.WHERE
            ret = IDENTIFIER(ps)
        else
            ret = INSTANCE(ps)
        end
        if (ret isa EXPR{OPERATOR{ColonOp,Tokens.COLON, false}}) && ps.nt.kind != Tokens.COMMA
            @catcherror ps startbyte ret = parse_unary(ps, ret)
        end
    elseif ps.t.kind == Tokens.AT_SIGN
        @catcherror ps startbyte ret = parse_macrocall(ps)
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.t.kind == Tokens.ENDMARKER
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected end of file")
    elseif ps.t.kind == Tokens.COMMA
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected comma")
    elseif ps.t.kind == Tokens.RPAREN
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected )")
    elseif ps.t.kind == Tokens.RBRACE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected }")
    elseif ps.t.kind == Tokens.RSQUARE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected ]")
    else
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unknown error")
    end

    while !closer(ps) && !(ps.closer.precedence == DotOp && ismacro(ret))
        @catcherror ps startbyte ret = parse_compound(ps, ret)
    end
    if ps.closer.precedence != DotOp && closer(ps) && ret isa EXPR{LITERAL{Tokens.MACRO}}
        ret = EXPR{MacroCall}(EXPR[ret], ret.span, Variable[], "")
    end

    return ret
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
    startbyte = ps.nt.startbyte - ret.span
    if ps.nt.kind == Tokens.FOR
        ret = parse_generator(ps, ret)
    elseif ps.nt.kind == Tokens.DO
        ret = parse_do(ps, ret)
    elseif isajuxtaposition(ps, ret)
        op = EXPR{OPERATOR{TimesOp,Tokens.STAR,false}}(EXPR[], 0, Variable[], "")
        ret = parse_operator(ps, ret, op)
    elseif ps.nt.kind == Tokens.LPAREN && isemptyws(ps.ws)
        ret = @closer ps paren parse_call(ps, ret)
    elseif ps.nt.kind == Tokens.LBRACE && isemptyws(ps.ws)
        ret = parse_curly(ps, ret)
    elseif ps.nt.kind == Tokens.LSQUARE && isemptyws(ps.ws) && !(ret isa EXPR{OPERATOR{p,k,dot}} where {p,k,dot})
        ret = @nocloser ps block parse_ref(ps, ret)
    elseif ps.nt.kind == Tokens.COMMA
        ret = parse_tuple(ps, ret)
    elseif isunaryop(ret) && ps.nt.kind != Tokens.EQ
        ret = parse_unary(ps, ret)
    elseif isoperator(ps.nt)
        next(ps)
        op = INSTANCE(ps)
        format_op(ps, precedence(ps.t))
        ret = parse_operator(ps, ret, op)
    elseif (ret isa EXPR{IDENTIFIER} || (ret isa EXPR{BinarySyntaxOpCall} && ret.args[2] isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}})) && (ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING)
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, ret)
        ret = EXPR{x_Str}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    # Suffix on x_str
    elseif ret isa EXPR{x_Str} && ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
        push!(ret.args, EXPR{LITERAL{Tokens.STRING}}(EXPR[], arg.span, Variable[], arg.val))
        ret.span += arg.span
    elseif (ret isa EXPR{IDENTIFIER} || (ret isa EXPR{BinarySyntaxOpCall} && ret.args[2] isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}})) && ps.nt.kind == Tokens.CMD
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, ret)
        ret = EXPR{x_Cmd}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    elseif ret isa EXPR{x_Cmd} && ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
        push!(ret.args, EXPR{LITERAL{Tokens.STRING}}(EXPR[], arg.span, Variable[], arg.val))
        ret.span += arg.span
    elseif ret isa EXPR{UnarySyntaxOpCall} && ret.args[2] isa EXPR{OPERATOR{16,Tokens.PRIME, d1}} where d1
        # prime operator followed by an identifier has an implicit multiplication
        @catcherror ps startbyte nextarg = @precedence ps 11 parse_expression(ps)
        ret = EXPR{BinaryOpCall}(EXPR[ret, EXPR{OPERATOR{TimesOp,Tokens.STAR,false}}(EXPR[], 0, Variable[], ""), nextarg], ret.span + nextarg.span, Variable[], "")
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.nt.kind == Tokens.ENDMARKER
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected end of file")
    elseif ps.nt.kind == Tokens.LPAREN
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected (")
    elseif ps.nt.kind == Tokens.RPAREN
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected )")
    elseif ps.nt.kind == Tokens.LBRACE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected {")
    elseif ps.nt.kind == Tokens.RBRACE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected }")
    elseif ps.nt.kind == Tokens.LSQUARE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected [")
    elseif ps.nt.kind == Tokens.RSQUARE
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected ]")
    elseif ret isa OPERATOR
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected operator")
    else
        ps.errored = true
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unknown error")
    end
    if ps.errored
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unknown error")
    end
    return ret
end

"""
    parse_list(ps)

Parses a list of comma seperated expressions finishing when the parent state
of `ps.closer` is met, newlines are ignored. Expects to start at the first item and ends on the last
item so surrounding punctuation must be handled externally.

**NOTE**
Should be replaced with the approach taken in `parse_call`
"""
function parse_list(ps::ParseState, puncs)
    startbyte = ps.nt.startbyte

    args = EXPR[]

    while !closer(ps)
        @catcherror ps startbyte a = @nocloser ps newline @closer ps comma parse_expression(ps)
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(puncs, INSTANCE(ps))
            format_comma(ps)
        end
    end

    if ps.t.kind == Tokens.COMMA
        format_comma(ps)
    end
    return args
end

"""
    parse_paren(ps, ret)

Parses an expression starting with a `(`.
"""
function parse_paren(ps::ParseState)
    startbyte = ps.t.startbyte

    ret = EXPR{TupleH}(EXPR[INSTANCE(ps)], - startbyte, Variable[], "")
    format_lbracket(ps)
    
    @catcherror ps startbyte @default ps @nocloser ps inwhere @closer ps paren parse_comma_sep(ps, ret, false, true)

    if length(ret.args) == 2 && !(ret.args[2] isa EXPR{UnarySyntaxOpCall} && ret.args[2].args[2] isa EXPR{OPERATOR{DddotOp,Tokens.DDDOT,false}})
        
        if ps.ws.kind != SemiColonWS || (length(ret.args) == 2 && ret.args[2] isa EXPR{Block})
            ret = EXPR{InvisBrackets}(ret.args, ret.span, Variable[], "")
        end
    end

    # handle closing ')'
    next(ps)
    push!(ret.args, INSTANCE(ps))
    format_rbracket(ps)
    
    ret.span = ps.nt.startbyte - startbyte

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
        x = EXPR{ERROR}(EXPR[], 0, Variable[], "Unknown error")
    end
    return x
end

function parse_doc(ps::ParseState)
    if ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING
        next(ps)
        doc = INSTANCE(ps)
        if (ps.nt.kind == Tokens.ENDMARKER || ps.nt.kind == Tokens.END)
            return doc
        elseif isbinaryop(ps.nt) && !closer(ps)
            @catcherror ps startbyte ret = parse_compound(ps, doc)
            return ret
        end

        ret = parse_expression(ps)
        ret = EXPR{MacroCall}(EXPR[GlobalRefDOC, doc, ret], doc.span + ret.span, Variable[], "")
    elseif ps.nt.kind == Tokens.IDENTIFIER && ps.nt.val == "doc" && (ps.nnt.kind == Tokens.STRING || ps.nnt.kind == Tokens.TRIPLE_STRING)
        next(ps)
        doc = INSTANCE(ps)
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, doc)
        doc = EXPR{x_Str}(EXPR[doc, arg], doc.span + arg.span, Variable[], "")
        ret = parse_expression(ps)
        ret = EXPR{MacroCall}(EXPR[GlobalRefDOC, doc, ret], doc.span + ret.span, Variable[], "")
    else
        ret = parse_expression(ps)
    end
    return ret
end

function parse(ps::ParseState, cont = false)
    if ps.l.io.size == 0
        return (cont ? EXPR{FileH}(EXPR[], 0, Variable[], "") : nothing), ps
    end
    last_line = 0
    curr_line = 0

    if cont
        top = EXPR{FileH}(EXPR[], 0, Variable[], "")
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            push!(top.args, EXPR{LITERAL{nothing}}(EXPR[], ps.nt.startbyte, Variable[], "comments"))
        end
        
        while !ps.done && !ps.errored
            curr_line = ps.nt.startpos[1]
            ret = parse_doc(ps)

            # join semicolon sep items
            if curr_line == last_line && last(top.args) isa EXPR{TopLevel}
                push!(last(top.args).args, ret)
                last(top.args).span += ret.span
            elseif ps.ws.kind == SemiColonWS
                push!(top.args, EXPR{TopLevel}(EXPR[ret], ret.span, Variable[], ""))
            else
                push!(top.args, ret)
            end
            last_line = curr_line
        end
        top.span += ps.nt.startbyte
    else
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            top = EXPR{LITERAL{nothing}}(EXPR[], ps.nt.startbyte, Variable[], "comments")
        else
            top = parse_doc(ps)
            last_line = ps.nt.startpos[1]
            if ps.ws.kind == SemiColonWS
                top = EXPR{TopLevel}(EXPR[top], top.span, Variable[], "")
                while ps.ws.kind == SemiColonWS && ps.nt.startpos[1] == last_line && ps.nt.kind != Tokens.ENDMARKER
                    ret = parse_doc(ps)
                    push!(top.args, ret)
                    top.span += ret.span
                    last_line = ps.nt.startpos[1]
                end
            end
        end
    end

    return top, ps
end


function parse_file(path::String)
    x = parse(readstring(path), true)
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



ischainable(t::Token) = t.kind == Tokens.PLUS || t.kind == Tokens.STAR || t.kind == Tokens.APPROX

# include("precompile.jl")
# _precompile_()
end

