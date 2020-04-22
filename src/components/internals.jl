const term_c = (Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE, Tokens.END, Tokens.ELSE, Tokens.ELSEIF, Tokens.CATCH, Tokens.FINALLY, Tokens.ENDMARKER)

"""
Continue parsing statements until an element of `closers` is hit (usually
`end`). Statements are grouped in a `Block` EXPR.
"""
function parse_block(ps::ParseState, ret::Vector{EXPR} = EXPR[], closers = (Tokens.END,), docable = false)
    while kindof(ps.nt) ∉ closers # loop until an expected closer is hit
        if kindof(ps.nt) ∈ term_c # error handling if an unexpected closer is hit
            if kindof(ps.nt) == Tokens.ENDMARKER
                break
            elseif kindof(ps.nt) == Tokens.RPAREN
                if length(ps.closer.cc) > 1 && :paren == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(ps, INSTANCE(next(ps)), UnexpectedToken))
                end
            elseif kindof(ps.nt) == Tokens.RBRACE
                if length(ps.closer.cc) > 1 && :brace == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(ps, INSTANCE(next(ps)), UnexpectedToken))
                end
            elseif kindof(ps.nt) == Tokens.RSQUARE
                if length(ps.closer.cc) > 1 && :square == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(ps, INSTANCE(next(ps)), UnexpectedToken))
                end
            else
                push!(ret, mErrorToken(ps, INSTANCE(next(ps)), UnexpectedToken))
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
function parse_iterator(ps::ParseState)
    startbyte = ps.nt.startbyte
    if kindof(ps.nt) == Tokens.OUTER && kindof(ps.nws) != EmptyWS && !Tokens.isoperator(kindof(ps.nnt))
        outer = INSTANCE(next(ps))
        arg = @closer ps :range @closer ps :ws parse_expression(ps)
        if is_range(arg)
            arg.args[1] = setparent!(EXPR(Outer, EXPR[outer, arg.args[1]]), arg)
            arg.fullspan += outer.fullspan
            arg.span = outer.fullspan + arg.span
        else # error handling - incorrect iterator specification
            ps.errored = true
            arg = EXPR(ErrorToken, EXPR[outer, arg])
            arg.meta = InvalidIterator
        end
    else
        arg = @closer ps :range @closer ps :ws parse_expression(ps)
    end
    return arg
end

"""
Parses a group of iterators e.g. used in a `for` loop or generator. Can allow
for a succeeding `Filter` expression.
"""
function parse_iterators(ps::ParseState, allowfilter = false)
    startbyte = ps.nt.startbyte
    arg = parse_iterator(ps)
    if (typof(arg) === Outer && !is_range(arg.args[2])) || !is_range(arg)
        # error handling - incorrect iterator specification
        arg = mErrorToken(ps, arg, InvalidIterator)
    elseif kindof(ps.nt) == Tokens.COMMA # we've hit a comma separated list of iterators.
        arg = EXPR(Block, EXPR[arg])
        while kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, arg)
            nextarg = parse_iterator(ps)
            if (typof(nextarg) === Outer && !is_range(nextarg.args[2])) || !is_range(nextarg)
                # error handling - incorrect iterator specification
                arg = mErrorToken(ps, arg, InvalidIterator)
            end
            push!(arg, nextarg)
        end
    end

    if allowfilter && kindof(ps.nt) === Tokens.IF # assumes we're inside a generator
        if typof(arg) === Block
            arg = EXPR(Filter, arg.args)
        else
            arg = EXPR(Filter, EXPR[arg])
        end
        push!(arg, mKEYWORD(next(ps)))
        cond = @closer ps :range parse_expression(ps)
        push!(arg, cond)
    end
    return arg
end

function is_range(x::EXPR)
    typof(x) === BinaryOpCall && (is_eq(x.args[2]) || is_in(x.args[2]) || is_elof(x.args[2]))
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret::EXPR, ismacro = false)
    sb = ps.nt.startbyte - ret.fullspan
    # special case for `new` call inside Type definitions, converts `new` to a keyword.
    if isidentifier(ret) && valof(ret) == "new" && :struct in ps.closer.cc 
        ret = mKEYWORD(Tokens.NEW, ret.fullspan, ret.span)
    elseif typof(ret) === Curly && valof(ret.args[1]) == "new" && :struct in ps.closer.cc
        ret.args[1] = setparent!(mKEYWORD(Tokens.NEW, ret.args[1].fullspan, ret.args[1].span), ret)
    elseif is_minus(ret) || is_not(ret)
        arg = @closer ps :unary @closer ps :inwhere @precedence ps PowerOp parse_expression(ps)
        if typof(arg) === TupleH
            pushfirst!(arg.args, ret)
            fullspan = ps.nt.startbyte - sb
            ret = EXPR(Call, arg.args, fullspan, fullspan - (last(arg.args).fullspan - last(arg.args).span))
        elseif typof(arg) === WhereOpCall && typof(arg.args[1]) === TupleH
            ret = mWhereOpCall(EXPR(Call, EXPR[ret; arg.args[1].args]), arg.args[2], arg.args[3:end])
        else
            ret = mUnaryOpCall(ret, arg)
        end
    elseif is_and(ret) || is_decl(ret) || is_exor(ret)
        arg = @precedence ps 20 parse_expression(ps)
        if is_exor(ret) && typof(arg) === TupleH && length(arg.args) == 3 && typof(arg.args[2]) === UnaryOpCall && is_dddot(arg.args[2].arg[2])
            arg = EXPR(InvisBrackets, arg.args)
        end
        ret = mUnaryOpCall(ret, arg)
    elseif is_issubt(ret) || is_issupt(ret)
        arg = @precedence ps PowerOp parse_expression(ps)
        ret = EXPR(Call, EXPR[ret; arg.args])
    else
        !ismacro && typof(ret) === MacroName && (ismacro = true)
        args = EXPR[ret, mPUNCTUATION(next(ps))]
        @closeparen ps @default ps parse_comma_sep(ps, args, !ismacro)
        accept_rparen(ps, args)
        fullspan = ps.nt.startbyte - sb
        ret = EXPR(ismacro ? MacroCall : Call, args, fullspan, fullspan - last(args).fullspan + last(args).span)
    end
    return ret
end

_do_kw_convert(ps, a) = !ps.closer.brace && typof(a) === BinaryOpCall && is_eq(a.args[2])
_kw_convert(a) = EXPR(Kw, EXPR[a.args[1], a.args[2], a.args[3]], a.fullspan, a.span)

"""
Parses a comma separated list, optionally allowing for conversion of 
assignment (`=`) expressions to `Kw`.
"""
function parse_comma_sep(ps::ParseState, args::Vector{EXPR}, kw = true, block = false, istuple = false)
    @nocloser ps :inwhere @nocloser ps :newline @closer ps :comma while !closer(ps)
        a = parse_expression(ps)
        if kw && _do_kw_convert(ps, a)
            a = _kw_convert(a)
        end
        push!(args, a)
        if kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, args)
        elseif kindof(ps.ws) == SemiColonWS
            break
        end
    end
    if istuple && length(args) > 2
        block = false
    end

    if kindof(ps.ws) == SemiColonWS
        if @nocloser ps :newline @closer ps :comma @nocloser ps :semicolon closer(ps)
            if block && !(length(args) == 1 && ispunctuation(args[1])) && !(typof(last(args)) === UnaryOpCall && is_dddot(last(args).args[2]))
                push!(args, EXPR(Block, EXPR[pop!(args)]))
            elseif kw && kindof(ps.nt) === Tokens.RPAREN
                push!(args, EXPR(Parameters, EXPR[], 0, 0))
            end
        else
            a = @nocloser ps :newline @closer ps :comma @nocloser ps :inwhere parse_expression(ps)
            if block && !(length(args) == 1 && ispunctuation(args[1])) && !(typof(last(args)) === UnaryOpCall && is_dddot(last(args).args[2])) && !(istuple && kindof(ps.nt) === Tokens.COMMA)
                args1 = EXPR[pop!(args), a]
                @nocloser ps :newline @closer ps :comma while @nocloser ps :semicolon !closer(ps)
                    a = parse_expression(ps)
                    push!(args1, a)
                end
                body = EXPR(Block, args1)
                push!(args, body)
                args = body
            else
                parse_parameters(ps, args, EXPR[a])
            end
        end
    end
    return 
end

"""
Parses parameter arguments for a function call (e.g. following a semicolon).
"""
function parse_parameters(ps::ParseState, args::Vector{EXPR}, args1::Vector{EXPR} = EXPR[]; usekw = true)
    if isempty(args1)
        sb = ps.nt.startbyte
        isfirst = true
    else
        sb = ps.nt.startbyte - args1[1].fullspan
        isfirst = false
    end
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
        if kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, args1)
        end
        if kindof(ps.ws) == SemiColonWS
            parse_parameters(ps, args1; usekw = usekw)
        end
        isfirst = true
    end
    if !isempty(args1)
        fullspan = ps.nt.startbyte - sb
        paras = EXPR(Parameters, args1, fullspan, fullspan - last(args1).fullspan + last(args1).span)
        push!(args, paras)
    end
    return
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    sb = ps.t.startbyte
    at = mPUNCTUATION(ps)
    if !isemptyws(ps.ws)
        mname = mErrorToken(ps, INSTANCE(next(ps)), UnexpectedWhiteSpace)
    else
        mname = EXPR(MacroName, EXPR[at, mIDENTIFIER(next(ps))])
    end

    # Handle cases with @ at start of dotted expressions
    if kindof(ps.nt) == Tokens.DOT && isemptyws(ps.ws)
        while kindof(ps.nt) == Tokens.DOT
            op = mOPERATOR(next(ps))
            nextarg = mIDENTIFIER(next(ps))
            mname = mBinaryOpCall(mname, op, EXPR(Quotenode, EXPR[nextarg]))
        end
    end

    if kindof(ps.nt) == Tokens.COMMA
        return EXPR(MacroCall, EXPR[mname], mname.fullspan, mname.span)
    elseif isemptyws(ps.ws) && kindof(ps.nt) == Tokens.LPAREN
        return parse_call(ps, mname, true)
    else
        args = EXPR[mname]
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            if insquare
                a = @closer ps :insquare @closer ps :inmacro @closer ps :ws @closer ps :wsop parse_expression(ps)
            else
                a = @closer ps :inmacro @closer ps :ws @closer ps :wsop parse_expression(ps)
            end
            push!(args, a)
            if insquare && kindof(ps.nt) == Tokens.FOR
                break
            end
        end
        fullspan = ps.nt.startbyte - sb
        return EXPR(MacroCall, args, fullspan, fullspan - last(args).fullspan + last(args).span)
    end
end




"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret::EXPR)
    kw = mKEYWORD(next(ps))
    ret = EXPR(Generator, EXPR[ret, kw])
    ranges = @closesquare ps parse_iterators(ps, true)

    if typof(ranges) === Block
        append!(ret, ranges)
    else
        push!(ret, ranges)
    end


    if typof(ret.args[1]) === Generator || typof(ret.args[1]) === Flatten
        ret = EXPR(Flatten, EXPR[ret])
    end

    return ret
end


"""
Helper function for parsing import/using statements.
"""
function parse_dot_mod(ps::ParseState, is_colon = false)
    args = EXPR[]

    while kindof(ps.nt) == Tokens.DOT || kindof(ps.nt) == Tokens.DDOT || kindof(ps.nt) == Tokens.DDDOT
        d = mOPERATOR(next(ps))
        trailing_ws = d.fullspan - d.span
        if is_dot(d)
            push!(args, mOPERATOR(1 + trailing_ws, 1, Tokens.DOT, false))
        elseif is_ddot(d)
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1 + trailing_ws, 1, Tokens.DOT, false))
        elseif is_dddot(d)
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1 + trailing_ws, 1, Tokens.DOT, false))
        end
    end

    # import/export ..
    if kindof(ps.nt) == Tokens.COMMA || kindof(ps.ws) == NewLineWS || kindof(ps.nt) == Tokens.ENDMARKER
        if length(args) == 2
            return EXPR[INSTANCE(ps)]
        end
    end

    while true
        if kindof(ps.nt) == Tokens.AT_SIGN
            at = mPUNCTUATION(next(ps))
            a = INSTANCE(next(ps))
            push!(args, EXPR(MacroName, EXPR[at, a]))
        elseif kindof(ps.nt) == Tokens.LPAREN
            a = EXPR(InvisBrackets, EXPR[mPUNCTUATION(next(ps))])
            push!(a, @closeparen ps parse_expression(ps))
            accept_rparen(ps, a)
            push!(args, a)
        elseif kindof(ps.nt) == Tokens.EX_OR
            a = @closer ps :comma parse_expression(ps)
            push!(args, a)
        elseif !is_colon && isoperator(ps.nt)
            next(ps)
            push!(args, mOPERATOR(ps.nt.startbyte - ps.t.startbyte,  1 + ps.t.endbyte - ps.t.startbyte, kindof(ps.t), false))
        elseif VERSION > v"1.3.0-" && isidentifier(ps.nt) && isemptyws(ps.nws) && (kindof(ps.nnt) === Tokens.STRING || kindof(ps.nnt) === Tokens.TRIPLE_STRING)
            push!(args, EXPR(NONSTDIDENTIFIER, EXPR[INSTANCE(next(ps)), INSTANCE(next(ps))]))
        else
            push!(args, INSTANCE(next(ps)))
        end

        if kindof(ps.nt) == Tokens.DOT
            push!(args, mPUNCTUATION(next(ps)))
        elseif isoperator(ps.nt) && (ps.nt.dotop || kindof(ps.nt) == Tokens.DOT)
            push!(args, mPUNCTUATION(Tokens.DOT, 1, 1))
            ps.nt = RawToken(kindof(ps.nt), ps.nt.startpos, ps.nt.endpos, ps.nt.startbyte + 1, ps.nt.endbyte, ps.nt.token_error, false, ps.nt.suffix)
        else
            break
        end
    end
    args
end
