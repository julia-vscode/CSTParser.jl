__precompile__()
module CSTParser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last, endof, +, isempty, getindex, setindex!
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState, parse_expression

include("hints.jl")
import .Hints: Hint, LintCodes, FormatCodes

include("lexer.jl")
include("errors.jl")
include("spec.jl")
include("utils.jl")
include("iterators.jl")
include("scoping.jl")
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
        if (ret isa OPERATOR{ColonOp, Tokens.COLON}) && ps.nt.kind != Tokens.COMMA
            @catcherror ps startbyte ret = parse_unary(ps, ret)
        end
    elseif ps.t.kind == Tokens.AT_SIGN
        @catcherror ps startbyte ret = parse_macrocall(ps)
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.t.kind == Tokens.ENDMARKER
        ps.errored = true
        return ERROR{UnexpectedEndmarker}(0, INSTANCE(ps))
    elseif ps.t.kind == Tokens.COMMA
        ps.errored = true
        return ERROR{UnexpectedComma}(0, INSTANCE(ps))
    elseif ps.t.kind == Tokens.RPAREN
        ps.errored = true
        return ERROR{UnexpectedRParen}(0, INSTANCE(ps))
    elseif ps.t.kind == Tokens.RBRACE
        ps.errored = true
        return ERROR{UnexpectedRBrace}(0, INSTANCE(ps))
    elseif ps.t.kind == Tokens.RSQUARE
        ps.errored = true
        return ERROR{UnexpectedRSquare}(0, INSTANCE(ps))
    else
        ps.errored = true
        return ERROR{UnknownError}(0, INSTANCE(ps))
    end

    while !closer(ps) && !(ps.closer.precedence == DotOp && ismacro(ret))
        @catcherror ps startbyte ret = parse_compound(ps, ret)
    end
    if ps.closer.precedence != DotOp && closer(ps) && ret isa LITERAL{Tokens.MACRO}
        ret = EXPR(MACROCALL, [ret], ret.span)
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
        @catcherror ps startbyte ret = parse_generator(ps, ret)
    elseif ps.nt.kind == Tokens.DO
        @catcherror ps startbyte ret = parse_do(ps, ret)
    elseif isajuxtaposition(ps, ret)
        op = OPERATOR{TimesOp, Tokens.STAR, false}(0)
        @catcherror ps startbyte ret = parse_operator(ps, ret, op)
    elseif ps.nt.kind == Tokens.LPAREN && isempty(ps.ws)
        @catcherror ps startbyte ret = @closer ps paren parse_call(ps, ret)
    elseif ps.nt.kind == Tokens.LBRACE && isempty(ps.ws)
        @catcherror ps startbyte ret = parse_curly(ps, ret)
    elseif ps.nt.kind == Tokens.LSQUARE && isempty(ps.ws) && !(ret isa OPERATOR)
        @catcherror ps startbyte ret = @nocloser ps block parse_ref(ps, ret)
    elseif ps.nt.kind == Tokens.COMMA
        @catcherror ps startbyte ret = parse_tuple(ps, ret)
    elseif isunaryop(ret) && ps.nt.kind != Tokens.EQ
        @catcherror ps startbyte ret = parse_unary(ps, ret)
    elseif isoperator(ps.nt)
        next(ps)
        op = INSTANCE(ps)
        format_op(ps, precedence(ps.t))
        @catcherror ps startbyte ret = parse_operator(ps, ret, op)
    elseif (ret isa IDENTIFIER || (ret isa EXPR && ret.head isa OPERATOR{DotOp, Tokens.DOT})) && (ps.nt.kind == Tokens.STRING || ps.nt.kind == Tokens.TRIPLE_STRING)
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, ret)
        ret = EXPR(x_STR, [ret, arg], ret.span + arg.span)
    # Suffix on x_str
    elseif ret isa EXPR && ret.head == x_STR && ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
        push!(ret.args, LITERAL{Tokens.STRING}(arg.span, arg.val))
        ret.span += arg.span
    elseif (ret isa IDENTIFIER || (ret isa EXPR && ret.head isa OPERATOR{DotOp, Tokens.DOT})) && ps.nt.kind == Tokens.CMD
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, ret)
        ret = EXPR(x_CMD, [ret, arg], ret.span + arg.span)
    elseif ret isa EXPR && ret.head == x_CMD && ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
        push!(ret.args, LITERAL{Tokens.STRING}(arg.span, arg.val))
        ret.span += arg.span
    elseif ret isa EXPR && ret.head isa OPERATOR{20, Tokens.PRIME} 
        # prime operator followed by an identifier has an implicit multiplication
        @catcherror ps startbyte nextarg = @precedence ps 11 parse_expression(ps)
        ret = EXPR(CALL, [OPERATOR{TimesOp, Tokens.STAR, false}(0), ret, nextarg], ret.span + nextarg.span)
################################################################################
# Everything below here is an error
################################################################################
    elseif ps.nt.kind == Tokens.ENDMARKER
        ps.errored = true
        return ERROR{UnexpectedEndmarker}(ret.span, ret)
    elseif ps.nt.kind == Tokens.LPAREN
        ps.errored = true
        return ERROR{UnexpectedLParen}(ret.span, ret)
    elseif ps.nt.kind == Tokens.RPAREN
        ps.errored = true
        return ERROR{UnexpectedRParen}(ret.span, ret)
    elseif ps.nt.kind == Tokens.LBRACE
        ps.errored = true
        return ERROR{UnexpectedLBrace}(ret.span, ret)
    elseif ps.nt.kind == Tokens.RBRACE
        ps.errored = true
        return ERROR{UnexpectedRBrace}(ret.span, ret)
    elseif ps.nt.kind == Tokens.LSQUARE
        ps.errored = true
        return ERROR{UnexpectedLSquare}(ret.span, ret)
    elseif ps.nt.kind == Tokens.RSQUARE
        ps.errored = true
        return ERROR{UnexpectedRSquare}(ret.span, ret)
    elseif ret isa OPERATOR
        ps.errored = true
        return ERROR{UnexpectedOperator}(ret.span, ret)
    else
        ps.errored = true
        return ERROR{UnknownError}(ret.span, ret)
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

    args = SyntaxNode[]

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

    ret = EXPR(TUPLE, [], - startbyte, [INSTANCE(ps)])
    format_lbracket(ps)
    
    @catcherror ps startbyte @default ps @nocloser ps inwhere @closer ps paren parse_comma_sep(ps, ret, false, true)

    if length(ret.args) == 1 && length(ret.punctuation) == 1 && !(ret.args[1] isa EXPR && ret.args[1].head isa OPERATOR{DddotOp, Tokens.DDDOT})
        # if ret.args[1] isa EXPR && ret.args[1].head isa OPERATOR{0, Tokens.DDDOT} && ps.ws.kind != SemiColonWS
        #     ret.args[1] = EXPR(TUPLE, [ret.args[1]], ret.args[1].span)
        # end
        if ps.ws.kind != SemiColonWS
            ret.head = HEAD{InvisibleBrackets}(0)
        end
    end

    # handle closing ')'
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
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
        x = ERROR{UnknownError}(ps.nt.startbyte, x)
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
        ret = EXPR(MACROCALL, [GlobalRefDOC, doc, ret], doc.span + ret.span)
    elseif ps.nt.kind == Tokens.IDENTIFIER && ps.nt.val == "doc" && (ps.nnt.kind == Tokens.STRING || ps.nnt.kind == Tokens.TRIPLE_STRING)
        next(ps)
        doc = INSTANCE(ps)
        next(ps)
        @catcherror ps startbyte arg = parse_string(ps, doc)
        doc = EXPR(x_STR, [doc, arg], doc.span + arg.span)
        ret = parse_expression(ps)
        ret = EXPR(MACROCALL, [GlobalRefDOC, doc, ret], doc.span + ret.span)
    else
        ret = parse_expression(ps)
    end
    return ret
end

function parse(ps::ParseState, cont = false)
    if ps.l.io.size == 0
        return (cont ? EXPR(FILE, [], 0) : nothing), ps
    end
    last_line = 0
    curr_line = 0

    if cont
        top = EXPR(FILE, [], 0)
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            push!(top.args, LITERAL{nothing}(ps.nt.startbyte, :nothing))
        end
        
        while !ps.done && !ps.errored
            curr_line = ps.nt.startpos[1]
            ret = parse_doc(ps)

            # join semicolon sep items
            if curr_line == last_line && last(top.args) isa EXPR && last(top.args).head == TOPLEVEL
                push!(last(top.args).args, ret)
                last(top.args).span += ret.span
            elseif ps.ws.kind == SemiColonWS
                push!(top.args, EXPR(TOPLEVEL, [ret], ret.span))
            else
                push!(top.args, ret)
            end
            last_line = curr_line
        end
        top.span += ps.nt.startbyte
    else
        if ps.nt.kind == Tokens.WHITESPACE || ps.nt.kind == Tokens.COMMENT
            next(ps)
            top = LITERAL{nothing}(ps.nt.startbyte, :nothing)
        else
            top = parse_doc(ps)
            last_line = ps.nt.startpos[1]
            if ps.ws.kind == SemiColonWS
                top = EXPR(TOPLEVEL, [top], top.span)
                while ps.ws.kind == SemiColonWS && ps.nt.startpos[1] == last_line
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
    
    File([], (f -> joinpath(dirname(path), f)).(_get_includes(x)), path, x, [])
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