const term_c = (Tokens.RPAREN, Tokens.RSQUARE, Tokens.RBRACE, Tokens.END, Tokens.ELSE, Tokens.ELSEIF, Tokens.CATCH, Tokens.FINALLY, Tokens.ENDMARKER)

function parse_block(ps::ParseState, ret::Vector{EXPR} = EXPR[], closers = (Tokens.END,), docable = false)
    while ps.nt.kind ∉ closers
        if ps.nt.kind ∈ term_c
            if ps.nt.kind == Tokens.ENDMARKER
                break
            elseif ps.nt.kind == Tokens.RPAREN
                if length(ps.closer.cc) > 1 && :paren == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(INSTANCE(next(ps)), UnexpectedToken))
                    ps.errored = true
                end
            elseif ps.nt.kind == Tokens.RBRACE
                if length(ps.closer.cc) > 1 && :brace == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(INSTANCE(next(ps)), UnexpectedToken))
                    ps.errored = true
                end
            elseif ps.nt.kind == Tokens.RSQUARE
                if length(ps.closer.cc) > 1 && :square == ps.closer.cc[end - 1]
                    break
                else
                    push!(ret, mErrorToken(INSTANCE(next(ps)), UnexpectedToken))
                    ps.errored = true
                end
            else
                push!(ret, mErrorToken(INSTANCE(next(ps)), UnexpectedToken))
                ps.errored = true
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


function parse_iter(ps::ParseState)
    startbyte = ps.nt.startbyte
    if ps.nt.kind == Tokens.OUTER && ps.nws.kind != EmptyWS && !Tokens.isoperator(ps.nnt.kind) 
        outer = INSTANCE(next(ps))
        arg = @closer ps range @closer ps ws parse_expression(ps)
        if is_range(arg)
            arg.args[1] = setparent!(EXPR(Outer, EXPR[outer, arg.args[1]]), arg)
            arg.fullspan += outer.fullspan
            arg.span = outer.fullspan + arg.span
        else
            arg = EXPR(ErrorToken, EXPR[outer, arg])
        end
    else
        arg = @closer ps range @closer ps ws parse_expression(ps)
    end
    return arg
end

function parse_ranges(ps::ParseState, allowfilter = false)
    startbyte = ps.nt.startbyte
    arg = parse_iter(ps)
    setiterbinding!(arg)
    if (arg.typ === Outer && !is_range(arg.args[2])) || !is_range(arg)
        arg = mErrorToken(arg, InvalidIterator)
        ps.errored = true
    elseif ps.nt.kind == Tokens.COMMA
        arg = EXPR(Block, EXPR[arg])
        while ps.nt.kind == Tokens.COMMA
            accept_comma(ps, arg)
            nextarg = parse_iter(ps)
            setiterbinding!(nextarg)
            if (nextarg.typ === Outer && !is_range(nextarg.args[2])) || !is_range(nextarg)
                arg = mErrorToken(arg, InvalidIterator)
                ps.errored = true
            end
            push!(arg, nextarg)
        end
    end

    if allowfilter && ps.nt.kind === Tokens.IF
        if arg.typ === Block
            arg = EXPR(Filter, arg.args)
        else
            arg = EXPR(Filter, EXPR[arg])
        end
        push!(arg, mKEYWORD(next(ps)))
        cond = @closer ps range parse_expression(ps)
        push!(arg, cond)
    end
    return arg
end

function is_range(x)
    x.typ === BinaryOpCall && (is_eq(x.args[2]) || is_in(x.args[2]) || is_elof(x.args[2]))
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret, ismacro = false)
    sb = ps.nt.startbyte - ret.fullspan
    if ret.typ === IDENTIFIER && ret.val == "new" && :struct in ps.closer.cc
        ret = mKEYWORD(Tokens.NEW, ret.fullspan, ret.span)
    elseif ret.typ === Curly && ret.args[1].val == "new" && :struct in ps.closer.cc
        ret.args[1] = setparent!(mKEYWORD(Tokens.NEW, ret.args[1].fullspan, ret.args[1].span), ret)
    end
    if is_minus(ret) || is_not(ret)
        arg = @closer ps unary @closer ps inwhere @precedence ps 13 parse_expression(ps)
        if arg.typ === TupleH
            pushfirst!(arg.args, ret)
            fullspan = ps.nt.startbyte - sb
            ret = EXPR(Call, arg.args, fullspan, fullspan - (last(arg.args).fullspan - last(arg.args).span))
        elseif arg.typ === WhereOpCall && arg.args[1].typ === TupleH
            ret = mWhereOpCall(EXPR(Call, EXPR[ret; arg.args[1].args]), arg.args[2], arg.args[3:end])
        else
            ret = mUnaryOpCall(ret, arg)
        end
    elseif is_and(ret) || is_decl(ret) || is_exor(ret) 
        arg = @precedence ps 20 parse_expression(ps)
        if is_exor(ret) && arg.typ === TupleH && length(arg.args) == 3 && arg.args[2].typ === UnaryOpCall && is_dddot(arg.args[2].arg[2])
            arg = EXPR(InvisBrackets, arg.args)
        end
        ret = mUnaryOpCall(ret, arg)
    elseif is_issubt(ret) || is_issupt(ret)
        arg = @precedence ps PowerOp parse_expression(ps)
        ret = EXPR(Call, EXPR[ret; arg.args])
    else
        !ismacro && ret.typ === MacroName && (ismacro = true)
        args = EXPR[ret, mPUNCTUATION(next(ps))]
        @closeparen ps @default ps parse_comma_sep(ps, args, !ismacro)
        accept_rparen(ps, args)
        fullspan = ps.nt.startbyte - sb
        ret = EXPR(ismacro ? MacroCall : Call, args, fullspan, fullspan - last(args).fullspan + last(args).span)
    end
    return ret
end


function parse_comma_sep(ps::ParseState, args::Vector{EXPR}, kw = true, block = false, istuple = false)
    @nocloser ps inwhere @nocloser ps newline @closer ps comma while !closer(ps)
        a = parse_expression(ps)

        if kw && !ps.closer.brace && a.typ === BinaryOpCall && is_eq(a.args[2])
            a = EXPR(Kw, EXPR[a.args[1], a.args[2], a.args[3]], a.fullspan, a.span)
        end
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            accept_comma(ps, args)
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        if block && !(istuple && length(args) > 2) && !(length(args) == 1 && ispunctuation(args[1])) && !(last(args).typ === UnaryOpCall && is_dddot(last(args).args[2]))
            args1 = EXPR[pop!(args)]
            @nocloser ps newline @closer ps comma while @nocloser ps semicolon !closer(ps)
                a = parse_expression(ps)
                push!(args1, a)
            end
            body = EXPR(Block, args1)
            push!(args, body)
            args = body
        else
            parse_parameters(ps, args)
        end
    end
    return #args
end

function parse_parameters(ps, args::Vector{EXPR})
    sb = ps.nt.startbyte
    args1 = EXPR[]
    @nocloser ps inwhere @nocloser ps newline  @closer ps comma while @nocloser ps semicolon !closer(ps)
        a = parse_expression(ps)
        if !ps.closer.brace && a.typ === BinaryOpCall && is_eq(a.args[2])
            a = EXPR(Kw, EXPR[a.args[1], a.args[2], a.args[3]], a.fullspan, a.span)
        end
        push!(args1, a)
        if ps.nt.kind == Tokens.COMMA
            accept_comma(ps, args1)
        end
        if ps.ws.kind == SemiColonWS
            parse_parameters(ps, args1)
        end
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
        mname = mErrorToken(INSTANCE(next(ps)), UnexpectedWhiteSpace)
        ps.errored = true
    else
        mname = EXPR(MacroName, EXPR[at, mIDENTIFIER(next(ps))])
    end

    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isemptyws(ps.ws)
        while ps.nt.kind == Tokens.DOT
            op = mOPERATOR(next(ps))
            nextarg = mIDENTIFIER(next(ps))
            mname = mBinaryOpCall(mname, op, EXPR(Quotenode, EXPR[nextarg]))
        end
    end

    if ps.nt.kind == Tokens.COMMA
        return EXPR(MacroCall, EXPR[mname], mname.fullspan, mname.span)
    elseif isemptyws(ps.ws) && ps.nt.kind == Tokens.LPAREN
        return parse_call(ps, mname, true)
    else
        args = EXPR[mname]
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            a = @closer ps inmacro @closer ps ws @closer ps wsop parse_expression(ps)
            push!(args, a)
            if insquare && ps.nt.kind == Tokens.FOR
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
function parse_generator(ps::ParseState, @nospecialize ret)
    kw = mKEYWORD(next(ps))
    ret = EXPR(Generator, EXPR[ret, kw])
    ranges = @closesquare ps parse_ranges(ps, true)

    if ranges.typ === Block
        append!(ret, ranges)
    else
        push!(ret, ranges)
    end
    

    if ret.args[1].typ === Generator || ret.args[1].typ === Flatten
        ret = EXPR(Flatten, EXPR[ret])
    end

    return setscope!(ret)
end



function parse_dot_mod(ps::ParseState, is_colon = false)
    args = EXPR[]

    while ps.nt.kind == Tokens.DOT || ps.nt.kind == Tokens.DDOT || ps.nt.kind == Tokens.DDDOT
        d = mOPERATOR(next(ps))
        if is_dot(d)
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
        elseif is_ddot(d)
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
        elseif is_dddot(d)
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
            push!(args, mOPERATOR(1, 1, Tokens.DOT, false))
        end
    end

    # import/export ..
    if ps.nt.kind == Tokens.COMMA || ps.ws.kind == NewLineWS || ps.nt.kind == Tokens.ENDMARKER
        if length(args) == 2
            return EXPR[INSTANCE(ps)]
        end
    end

    while true
        if ps.nt.kind == Tokens.AT_SIGN
            at = mPUNCTUATION(next(ps))
            a = INSTANCE(next(ps))
            push!(args, EXPR(MacroName, EXPR[at, a]))
        elseif ps.nt.kind == Tokens.LPAREN
            a = EXPR(InvisBrackets, EXPR[mPUNCTUATION(next(ps))])
            push!(a, @closeparen ps parse_expression(ps))
            accept_rparen(ps, a)
            push!(args, a)
        elseif ps.nt.kind == Tokens.EX_OR
            a = @closer ps comma parse_expression(ps)
            push!(args, a)
        elseif !is_colon && isoperator(ps.nt)
            next(ps)
            push!(args, mOPERATOR(ps.nt.startbyte - ps.t.startbyte,  1 + ps.t.endbyte - ps.t.startbyte, ps.t.kind, false))
        else
            push!(args, INSTANCE(next(ps)))
        end

        if ps.nt.kind == Tokens.DOT
            push!(args, mPUNCTUATION(next(ps)))
        elseif isoperator(ps.nt) && (ps.nt.dotop || ps.nt.kind == Tokens.DOT)
            push!(args, mPUNCTUATION(Tokens.DOT, 1, 1))
            ps.nt = RawToken(ps.nt.kind, ps.nt.startpos, ps.nt.endpos, ps.nt.startbyte + 1, ps.nt.endbyte, ps.nt.token_error, false)
        else
            break
        end
    end
    args
end
