module Parser
global debug = true

using Tokenize
import Base: next, start, done, length, first, last
import Tokenize.Tokens
import Tokenize.Tokens: Token, iskeyword, isliteral, isoperator
import Tokenize.Lexers: Lexer, peekchar, iswhitespace

export ParseState

include("parsestate.jl")
include("utils.jl")
include("spec.jl")
include("conversion.jl")
include("operators.jl")
include("keywords.jl")
include("positional.jl")
include("display.jl")

function parse_expression(ps::ParseState)
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords 
        ret = parse_kw_syntax(next(ps))
    elseif ps.nt.kind == Tokens.LPAREN
        ret = @default ps @closer ps paren parse_expression(next(ps))
        next(ps)
    elseif ps.nt.kind == Tokens.LSQUARE
        start = ps.nt.startbyte
        ret = @default ps @closer ps square parse_expression(next(ps))
        if ret isa EXPR && ret.head==TUPLE && ret.loc.start==start
            ret = EXPR(VECT, ret.args, LOCATION(start, ps.nt.endbyte))
        else
            ret = EXPR(VECT, [ret], LOCATION(start, ps.nt.endbyte))
        end
        next(ps)
    elseif isinstance(ps.nt)
        ret = INSTANCE(next(ps))
    elseif isunaryop(ps.nt)
        ret = parse_unary(next(ps))
    elseif ps.nt.kind==Tokens.AT_SIGN
        start = ps.nt.startbyte
        next(ps)
        ret = EXPR(MACROCALL, [INSTANCE(next(ps))], LOCATION(start, 0))
        isempty(ps.ws.val) && !closer(ps) && error("invalid macro name")
        while !closer(ps)
            a = @closer ps ws parse_expression(ps)
            push!(ret.args, a)
        end
    else
        error("Expression started with $(ps)")
    end


    while !closer(ps)
        if isoperator(ps.nt)
            if ps.formatcheck && isassignment(ps.nt) && ps.ws.val==""
                push!(ps.hints, "add space at $(ps.nt.startbyte)")
            end
            ret = parse_operator(ps, ret)
        elseif ps.nt.kind==Tokens.LPAREN
            if isempty(ps.ws.val)
                ret = @default ps @closer ps paren parse_call(ps, ret)
            else
                error("space before \"(\" not allowed in \"$(Expr(ret)) (\"")
            end
        elseif ps.nt.kind==Tokens.LBRACE
            if isempty(ps.ws.val)
                next(ps)
                args = @closer ps brace parse_list(ps)
                next(ps)
                ret = EXPR(CURLY, [ret, args...], LOCATION(ret.loc.start, ps.t.endbyte))
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind==Tokens.LSQUARE
            if isempty(ps.ws.val)
                start = ps.nt.startbyte
                next(ps)
                arg = @default ps @closer ps square parse_expression(ps)
                @assert ps.nt.kind==Tokens.RSQUARE
                next(ps)
                ret = EXPR(REF, [ret, arg], LOCATION(start, ps.t.endbyte))
            else
                error("space before \"{\" not allowed in \"$(Expr(ret)) {\"")
            end
        elseif ps.nt.kind == Tokens.COMMA
            if ps.formatcheck && ps.ws.val!=""
                push!(ps.hints, "remove whitespace at $(ps.nt.startbyte)")
            end
            next(ps)
            if isassignment(ps.nt)
                if ret isa EXPR && ret.head!=TUPLE
                    ret =  EXPR(TUPLE, [ret], LOCATION(ret.loc.start, ps.t.endbyte))
                end
            else
                nextarg = @closer ps tuple parse_expression(ps)
                if ret isa EXPR && ret.head==TUPLE
                    push!(ret.args, nextarg)
                    ret.loc.stop = nextarg.loc.stop
                else
                    ret =  EXPR(TUPLE, [ret, nextarg], LOCATION(ret.loc.start, nextarg.loc.stop))
                end
            end
        elseif ps.nt.kind == Tokens.FOR 
            ret = parse_generator(ps, ret)
        else
            for s in stacktrace()
                println(s)
            end
            error("infinite loop $(ps)")
        end
    end

    return ret
end

function parse_call(ps::ParseState, ret)
    next(ps)
    args = @closer ps paren parse_list(ps)
    next(ps)
    ret = EXPR(CALL, [ret, args...], LOCATION(ret.loc.start, ps.t.endbyte))
    if ps.nt.kind==Tokens.EQ
        next(ps)
        op = INSTANCE(ps)
        body = parse_expression(ps)
        if !(body isa EXPR) || body.head!= BLOCK
            body = EXPR(BLOCK, [body], LOCATION(body.loc.start, body.loc.stop))
        end
        ret = EXPR(op, [ret, body], LOCATION(ret.loc.start, body.loc.stop))
    end
    return ret
end

"""
    parse_list(ps)

Parses a list of comma seperated expressions finishing when the parent state
of `ps.closer` is met. Expects to start at the first item and ends on the last
item so surrounding punctuation must be handled externally.
"""
function parse_list(ps::ParseState)
    args = Expression[]
    while !closer(ps)
        a = @closer ps comma parse_expression(ps)
        push!(args, a)
        ps.nt.kind==Tokens.COMMA && next(ps)
    end
    return args
end


"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    @assert length(ps.ws.val)>0
    next(ps)
    op = INSTANCE(ps)
    range = parse_expression(ps)
    if range.head==CALL && range.args[1] isa INSTANCE && range.args[1].val=="in" || range.args[1].val=="∈"
        range = EXPR(INSTANCE{OPERATOR}("=", range.args[1].ws, range.args[1].loc, range.args[1].prec), range.args[2:3], range.loc)
    end

    ret = EXPR(INSTANCE{KEYWORD}("generator", op.ws, op.loc, op.prec), [ret, range])
    if !(ps.nt.kind==Tokens.RPAREN || ps.nt.kind==Tokens.RSQUARE)
        error("generator/comprehension syntax not followed by ')' or ']'")
    end
    return ret
end


"""
    parseblocks(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret = EXPR(BLOCK, [], LOCATION(0, 0)))
    start = ps.t.startbyte
    while ps.nt.kind!==Tokens.END
        push!(ret.args, @closer ps block parse_expression(ps))
    end
    @assert ps.nt.kind==Tokens.END
    ret.loc = LOCATION(isempty(ret.args) ? ps.nt.startbyte : first(ret.args).loc.start, ps.nt.endbyte)
    return ret
end


function parse(str::String, cont = false)
    # if isfile(str)
    #     ps = Parser.ParseState(readstring(str))
    # else
        ps = Parser.ParseState(str)
    # end
    # if cont
    #     ret = EXPR(BLOCK, [], LOCATION(0,0))
    #     while ps.nt.kind!=Tokens.ENDMARKER
    #         push!(ret.args, parse_expression(ps))
    #     end
    #     ret.loc.stop = ps.t.endbyte
    # else 
        ret = parse_expression(ps)
    # end
    return ret
end


ischainable(t::Token) = t.val == "+" || t.val == "*" || t.val == "~"
LtoR(prec::Int) = 1 ≤ prec ≤ 5 || prec == 13




end