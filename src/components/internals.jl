const term_c = (Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE, Tokens.END, Tokens.ELSE, Tokens.ELSEIF, Tokens.CATCH, Tokens.FINALLY, Tokens.ENDMARKER)

"""
Continue parsing statements until an element of `closers` is hit (usually
`end`). Statements are grouped in a `Block` EXPR.
"""
function parse_block(ps::ParseState, ret::Vector{EXPR} = EXPR[], closers = (Tokens.END,), docable = false)
    while kindof(ps.nt) ∉ closers # loop until an expected closer is hit
        if kindof(ps.nt) ∈ term_c # error handling if an unexpected closer is hit
            if kindof(ps.nt) === Tokens.ENDMARKER
                break
            else
                push!(ret, mErrorToken(ps, EXPR(next(ps)), UnexpectedToken))
            end
        else
            if docable
                a = parse_doc(ps)
            else
                a = parse_expression(ps)
            end
            push!(ret, a)
        end
    end
    return ret
end

"""
Parses an iterator, allowing for the preceding keyword `outer`. Returns an
error expression if an invalid expression is parsed (anything other than
`=`, `in`, `∈`).
"""
function parse_iterator(ps::ParseState, outer = parse_outer(ps))
    arg = @closer ps :range @closer ps :ws parse_expression(ps)
    if !is_range(arg)
        arg = mErrorToken(ps, arg, InvalidIterator)
    else 
        arg = adjust_iter(arg)
    end
    if outer !== nothing
        arg.args[1] = setparent!(EXPR(:Outer, EXPR[arg.args[1]], EXPR[outer]), arg)
        arg.fullspan += outer.fullspan
        arg.span = outer.fullspan + arg.span
    end
    return arg
end

function adjust_iter(x::EXPR)
    # Assumes x is a valid iterator
    if x.head === :Call # isoperator(x.args[1]) && x.args[1].val in ("in", "∈")
        EXPR(EXPR(:OPERATOR, 0, 0, "="), EXPR[x.args[2], x.args[3]], EXPR[x.args[1]])
    else 
        x
    end
end

"""
    is_range(x::EXPR)

Is `x` a valid iterator for use in `for` loops or generators?
"""
is_range(x::EXPR) = (isoperator(x.head) && is_eq(x.head)) || (x.head === :Call && (is_in(x.args[1]) || is_elof(x.args[1])))

function parse_outer(ps)
    if kindof(ps.nt) === Tokens.OUTER && kindof(ps.nws) !== EmptyWS && !Tokens.isoperator(kindof(ps.nnt))
        outer = EXPR(next(ps))
    end
end

"""
    parse_iterators(ps::ParseState, allowfilter = false)

Parses a group of iterators e.g. used in a `for` loop or generator. Can allow
for a succeeding `Filter` expression.
"""
function parse_iterators(ps::ParseState, allowfilter = false)
    arg = parse_iterator(ps)
    if iscomma(ps.nt) # we've hit a comma separated list of iterators.
        arg = EXPR(:Block, EXPR[arg])
        while iscomma(ps.nt)
            pushtotrivia!(arg, accept_comma(ps))
            nextarg = parse_iterator(ps)
            push!(arg, nextarg)
        end
    end

    if allowfilter
        arg = parse_filter(ps, arg)
    end
    return arg
end

"""
parse_filter(ps::ParseState, arg)

Parse a conditional filter following a generator.
"""
function parse_filter(ps::ParseState, arg)
    if kindof(ps.nt) === Tokens.IF # assumes we're inside a generator
        trivia = EXPR[EXPR(next(ps))]
        cond = @closer ps :range parse_expression(ps)
        if headof(arg) === :Block
            arg = EXPR(:Filter, EXPR[cond; arg.args], trivia)
        else
            arg = EXPR(:Filter, EXPR[cond, arg], trivia)
        end
    end
    return arg
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret::EXPR, ismacro = false)
    if is_minus(ret) || is_not(ret)
        arg = @closer ps :unary @closer ps :inwhere @precedence ps PowerOp parse_expression(ps)
        if istuple(arg)
            pushfirst!(arg.args, ret)
            ret = EXPR(:Call, arg.args, arg.trivia)
        elseif iswherecall(arg) && istuple(arg.args[1])
            ret = mWhereOpCall(EXPR(:Call, EXPR[ret; arg.args[1].args]), arg.args[2], arg.args[3:end])
        else
            ret = mUnaryOpCall(ret, arg)
        end
    elseif is_and(ret) || is_decl(ret) || is_exor(ret)
        arg = @precedence ps 20 parse_expression(ps)
        if is_exor(ret) && istuple(arg) && length(arg) == 3 && is_splat(arg.args[2])
            arg = EXPR(:Brackets, arg.args)
        end
        # ret = mUnaryOpCall(ret, arg)
        ret = EXPR(ret, EXPR[arg], nothing)
    elseif is_issubt(ret) || is_issupt(ret)
        arg = @precedence ps PowerOp parse_expression(ps)
        ret = EXPR(ret, arg.args, arg.trivia)
    else
        !ismacro && headof(ret) === :MacroName && (ismacro = true)
        args = ismacro ? EXPR[ret, EXPR(:NOTHING, 0, 0)] : EXPR[ret] 
        trivia = EXPR[EXPR(next(ps))]
        @closeparen ps @default ps parse_comma_sep(ps, args, trivia, !ismacro)
        accept_rparen(ps, trivia)
        ret = EXPR(ismacro ? :MacroCall : :Call, args, trivia)
    end
    return ret
end

"""
Parses a comma separated list, optionally allowing for conversion of 
assignment (`=`) expressions to `Kw`.
"""
function parse_comma_sep(ps::ParseState, args::Vector{EXPR}, trivia::Vector{EXPR}, kw = true, block = false, istuple = false; insertfirst = false)
    @nocloser ps :inwhere @nocloser ps :newline @closer ps :comma while !closer(ps)
        a = parse_expression(ps)
        if kw && _do_kw_convert(ps, a)
            a = _kw_convert(a)
        end
        push!(args, a)
        if iscomma(ps.nt)
            accept_comma(ps, trivia)
        elseif kindof(ps.ws) == SemiColonWS
            break
        end
    end
    if istuple && length(args) > 1
        block = false
    end

    if kindof(ps.ws) == SemiColonWS
        if @nocloser ps :newline @closer ps :comma @nocloser ps :semicolon closer(ps)
            if block && !(length(args) == 0 && ispunctuation(trivia[1])) && !(isunarycall(last(args)) && is_dddot(last(args).args[2]))
                push!(args, EXPR(:Block, EXPR[pop!(args)]))
            elseif kw && kindof(ps.nt) === Tokens.RPAREN
                push!(args, EXPR(:Parameters, EXPR[], nothing, 0, 0))
            end
        else
            a = @nocloser ps :newline @closer ps :comma @nocloser ps :inwhere parse_expression(ps)
            if block && !(length(args) == 0 && ispunctuation(trivia[1])) && !is_splat(last(args)) && !(istuple && iscomma(ps.nt))
                args1 = EXPR[pop!(args), a]
                @nocloser ps :newline @closer ps :comma while @nocloser ps :semicolon !closer(ps)
                    a = parse_expression(ps)
                    push!(args1, a)
                end
                body = EXPR(:Block, args1)
                push!(args, body)
                args = body
            else
                parse_parameters(ps, args, EXPR[a], insertfirst)
            end
        end
    end
    return
end

"""
    parse_parameters(ps::ParseState, args::Vector{EXPR}, args1::Vector{EXPR} = EXPR[]; usekw = true)

Parses parameter arguments for a function call (e.g. following a semicolon).
"""
function parse_parameters(ps::ParseState, args::Vector{EXPR}, args1::Vector{EXPR} = EXPR[], insertfirst = false; usekw = true)
    trivia = EXPR[]
    isfirst = isempty(args1)
    @nocloser ps :inwhere @nocloser ps :newline  @closer ps :comma while !isfirst || (@nocloser ps :semicolon !closer(ps))
        if isfirst
            a = parse_expression(ps)
        else
            a = first(args1)
        end
        if usekw && _do_kw_convert(ps, a)
            a = _kw_convert(a)
        end
        if isfirst
            push!(args1, a)
        else
            pop!(args1)
            push!(args1, a)
        end
        if iscomma(ps.nt)
            accept_comma(ps, trivia)
        end
        if kindof(ps.ws) == SemiColonWS
            parse_parameters(ps, args1; usekw = usekw)
        end
        isfirst = true
    end
    if !isempty(args1)
        insert!(args, insertfirst ? 1 : 2, EXPR(:Parameters, args1, trivia))
    end
    return
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    at = EXPR(ps)
    if !isemptyws(ps.ws)
        mname = mErrorToken(ps, INSTANCE(next(ps)), UnexpectedWhiteSpace)
    else
        mname = EXPR(:MacroName, EXPR[at, EXPR(:IDENTIFIER, next(ps))], nothing)
    end

    # Handle cases with @ at start of dotted expressions
    if kindof(ps.nt) === Tokens.DOT && isemptyws(ps.ws)
        while kindof(ps.nt) === Tokens.DOT
            op = EXPR(:OPERATOR, next(ps))
            nextarg = EXPR(:IDENTIFIER, next(ps))
            mname = EXPR(op, EXPR[mname, EXPR(:Quotenode, EXPR[nextarg], nothing)], nothing)
        end
    end

    if iscomma(ps.nt)
        return EXPR(:MacroCall, EXPR[mname], nothing, mname.fullspan, mname.span)
    elseif isemptyws(ps.ws) && kindof(ps.nt) === Tokens.LPAREN
        return parse_call(ps, mname, true)
    else
        args = EXPR[mname, EXPR(:NOTHING, 0, 0)]
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            if insquare
                a = @closer ps :insquare @closer ps :inmacro @closer ps :ws @closer ps :wsop parse_expression(ps)
            else
                a = @closer ps :inmacro @closer ps :ws @closer ps :wsop parse_expression(ps)
            end
            push!(args, a)
            if insquare && kindof(ps.nt) === Tokens.FOR
                break
            end
        end
        return EXPR(:MacroCall, args, nothing)
    end
end

"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, arg::EXPR)
    kw = EXPR(next(ps))
    ranges = @closesquare ps parse_iterators(ps, true)
    if headof(arg) === :Generator && !(headof(arg.args[1]) in (:Generator, :Flatten))
        arg.args[1] = EXPR(:Generator, EXPR[arg.args[1], ranges], EXPR[kw])
        update_span!(arg)
        ret = EXPR(:Flatten, EXPR[arg], nothing)
    elseif headof(arg) === :Generator || headof(arg) === :Flatten
        arg1, arg2 = get_appropriate_child_to_expand(arg)
        arg2.args[1] = EXPR(:Generator, EXPR[arg2.args[1], ranges], EXPR[kw])
        update_span!(arg2)
        arg1.args[1] = EXPR(:Flatten, EXPR[arg2], nothing)
        update_span!(arg1)
        update_span!(arg)
        ret = arg
    else
        ret = EXPR(:Generator, EXPR[arg], EXPR[kw])
        if headof(ranges) === :Block
            append!(ret.args, ranges.args)
            append!(ret.trivia, ranges.trivia)
            update_span!(ret)
        else
            push!(ret, ranges)
        end
    end
    return ret
end

function get_appropriate_child_to_expand(x)
    if headof(x) === :Generator && !(headof(x.args[1]) in (:Generator, :Flatten))
        return x, x.args[1]
    elseif headof(x) === :Flatten &&  headof(x.args[1]) === :Generator && headof(x.args[1].args[1]) === :Generator
        x.args[1], x.args[1].args[1]
    else
        get_appropriate_child_to_expand(x.args[1])
    end
end

function parse_importexport_item(ps, is_colon = false)
    if kindof(ps.nt) === Tokens.AT_SIGN
        at = EXPR(next(ps))
        a = INSTANCE(next(ps))
        EXPR(:MacroName, EXPR[at, a],nothing)
    elseif kindof(ps.nt) === Tokens.LPAREN
        a = EXPR(:Brackets, EXPR[], EXPR[EXPR(next(ps))])
        push!(a, @closeparen ps parse_expression(ps))
        pushtotrivia!(a, accept_rparen(ps))
        a
    elseif kindof(ps.nt) === Tokens.EX_OR
        a = @closer ps :comma parse_expression(ps)
        a
    elseif !is_colon && isoperator(ps.nt)
        next(ps)
        EXPR(:OPERATOR, ps.nt.startbyte - ps.t.startbyte,  1 + ps.t.endbyte - ps.t.startbyte, val(ps.t, ps))
    elseif VERSION > v"1.3.0-" && isidentifier(ps.nt) && isemptyws(ps.nws) && (kindof(ps.nnt) === Tokens.STRING || kindof(ps.nnt) === Tokens.TRIPLE_STRING)
        EXPR(:NonStdIdentifier, EXPR[INSTANCE(next(ps)), INSTANCE(next(ps))])
        #TODO fix nonstdid handling
    else
        INSTANCE(next(ps))
    end
end
"""
Helper function for parsing import/using statements.
"""
function parse_dot_mod(ps::ParseState, is_colon = false)
    ret = EXPR(EXPR(:OPERATOR, 0, 0, "."), EXPR[], EXPR[])

    while kindof(ps.nt) === Tokens.DOT || kindof(ps.nt) === Tokens.DDOT || kindof(ps.nt) === Tokens.DDDOT
        d = EXPR(:OPERATOR, next(ps))
        trailing_ws = d.fullspan - d.span
        if is_dot(d)
            push!(ret, EXPR(:OPERATOR, 1 + trailing_ws, 1, "."))
        elseif is_ddot(d)
            push!(ret, EXPR(:OPERATOR, 1, 1, "."))
            push!(ret, EXPR(:OPERATOR, 1 + trailing_ws, 1, "."))
        elseif is_dddot(d)
            push!(ret, EXPR(:OPERATOR, 1, 1, "."))
            push!(ret, EXPR(:OPERATOR, 1, 1, "."))
            push!(ret, EXPR(:OPERATOR, 1 + trailing_ws, 1, "."))
        end
    end

    while true
        push!(ret, parse_importexport_item(ps, is_colon))

        if kindof(ps.nt) === Tokens.DOT
            pushtotrivia!(ret, EXPR(next(ps)))
        elseif isoperator(ps.nt) && (ps.nt.dotop || kindof(ps.nt) === Tokens.DOT)
            push!(ret, EXPR(:DOT, 1, 1))
            ps.nt = RawToken(kindof(ps.nt), ps.nt.startpos, ps.nt.endpos, ps.nt.startbyte + 1, ps.nt.endbyte, ps.nt.token_error, false, ps.nt.suffix)
        else
            break
        end
    end
    ret
end


"""
    parse_prefixed_string_cmd(ps::ParseState, ret::EXPR)

Parse prefixed strings and commands such as `pre"text"`.
"""
function parse_prefixed_string_cmd(ps::ParseState, ret::EXPR)
    arg = parse_string_or_cmd(next(ps), ret)
    
    if ret.head === :IDENTIFIER && valof(ret) == "var" && VERSION > v"1.3.0-"
        EXPR(:NonStdIdentifier, EXPR[ret, arg], nothing)
    else
        EXPR(:MacroCall, EXPR[EXPR(:IDENTIFIER, 0, 0, string("@", valof(ret), iscmd(arg) ? "_cmd" : "_str")), EXPR(:NOTHING, 0, 0), arg], EXPR[ret])
    end
end