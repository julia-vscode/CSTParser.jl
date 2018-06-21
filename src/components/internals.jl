"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token.
Returns `ps` the token before the closing `end`, the calling function is
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR{Block}, closers = (Tokens.END,), docable = false)
    parse_block(ps, ret.args, closers, docable)
    update_span!(ret)
    return 
end


function parse_block(ps::ParseState, ret::Vector{Any}, closers = (Tokens.END,), docable = false)
    # Parsing
    while !(ps.nt.kind in closers) && !ps.errored
        if ps.nt.kind == Tokens.ENDMARKER
            return error_eof(ps, ps.nt.startbyte, Diagnostics.UnexpectedBlockEnd, "Unexpected end of block")
        end
        if docable
            @catcherror ps a = parse_doc(ps)
        else
            @catcherror ps a = parse_expression(ps)
        end
        push!(ret, a)
    end
    return 
end


function parse_iter(ps::ParseState)
    startbyte = ps.nt.startbyte
    if ps.nt.kind == Tokens.OUTER && ps.nws.kind != EmptyWS && !Tokens.isoperator(ps.nnt.kind) 
        outer = INSTANCE(next(ps))
        arg = @closer ps range @closer ps ws parse_expression(ps)
        arg.arg1 = EXPR{Outer}([outer, arg.arg1])
        arg.fullspan += outer.fullspan
        arg.span = 1:(outer.fullspan + last(arg.span))
    else
        arg = @closer ps range @closer ps ws parse_expression(ps)
    end
    return arg
end

function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    #TODO: this is slow
    @catcherror ps arg = parse_iter(ps)

    if (arg isa EXPR{Outer} && !is_range(arg.args[2])) || !is_range(arg)
        return make_error(ps, broadcast(+, startbyte, (0:length(arg.span) .- 1)),
                          Diagnostics.InvalidIter, "invalid iteration specification")
    end
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(Any[arg])
        while ps.nt.kind == Tokens.COMMA
            push!(arg, PUNCTUATION(next(ps)))
            @catcherror ps nextarg = parse_iter(ps)
            if (nextarg isa EXPR{Outer} && !is_range(nextarg.args[2])) || !is_range(nextarg)
                return make_error(ps, startbyte .+ (0:length(arg.span) .- 1),
                                  Diagnostics.InvalidIter, "invalid iteration specification")
            end
            push!(arg, nextarg)
        end
    end
    return arg
end


function is_range(x) false end
function is_range(x::BinarySyntaxOpCall) is_eq(x.op) end
function is_range(x::BinaryOpCall) is_in(x.op) || is_elof(x.op) end

function parse_end(ps::ParseState)
    ret = IDENTIFIER(ps)
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(Any[])
    end
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, @nospecialize ret)
    if is_minus(ret) || is_not(ret)
        arg = @closer ps inwhere @precedence ps 13 parse_expression(ps)
        if arg isa EXPR{TupleH}
            return EXPR{Call}(Any[ret; arg.args])
        elseif arg isa WhereOpCall && arg.arg1 isa EXPR{TupleH}
            return WhereOpCall(EXPR{Call}(Any[ret; arg.arg1.args]), arg.op, arg.args)
        else
            return UnaryOpCall(ret, arg)
        end
    elseif is_and(ret) || is_decl(ret) || is_exor(ret) 
        arg = @precedence ps 20 parse_expression(ps)
        if is_exor(ret) && arg isa EXPR{TupleH} && length(arg.args) == 3 && arg.args[2] isa UnarySyntaxOpCall && is_dddot(arg.args[2].arg2)
            arg = EXPR{InvisBrackets}(arg.args)
        end
        return UnarySyntaxOpCall(ret, arg)
    elseif is_issubt(ret) || is_issupt(ret)
        arg = @precedence ps 13 parse_expression(ps)
        return EXPR{Call}(Any[ret; arg.args])
    end
    ismacro = ret isa EXPR{MacroName}
    args = Any[ret, PUNCTUATION(next(ps))]
    @default ps parse_comma_sep(ps, args, !ismacro)
    rparen = PUNCTUATION(next(ps))
    rparen.kind == Tokens.RPAREN || return error_unexpected(ps, ps.t)
    push!(args, rparen)
    return EXPR{ismacro ? MacroCall : Call}(args)
end


function parse_comma_sep(ps::ParseState, args::Vector{Any}, kw = true, block = false, istuple = false)
    @catcherror ps @nocloser ps inwhere @nocloser ps newline @closer ps comma while !closer(ps)
        a = parse_expression(ps)

        if kw && !ps.closer.brace && a isa BinarySyntaxOpCall && is_eq(a.op)
            a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
        end
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            push!(args, PUNCTUATION(next(ps)))
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        if block && !(istuple && length(args) > 2) && !(length(args) == 1 && args[1] isa PUNCTUATION) && !(last(args) isa UnarySyntaxOpCall && is_dddot(last(args).arg2))
            args1 = Any[pop!(args)]
            @nocloser ps newline @closer ps comma while @nocloser ps semicolon !closer(ps)
                @catcherror ps a = parse_expression(ps)
                push!(args1, a)
            end
            body = EXPR{Block}(args1)
            push!(args, body)
            return body
        else
            parse_parameters(ps, args)
        end
    end
    return args
end

function parse_parameters(ps, args::Vector{Any})
    args1 = Any[]
    @nocloser ps inwhere @nocloser ps newline  @closer ps comma while @nocloser ps semicolon !closer(ps)
        @catcherror ps a = parse_expression(ps)
        if !ps.closer.brace && a isa BinarySyntaxOpCall && is_eq(a.op)
            a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
        end
        push!(args1, a)
        if ps.nt.kind == Tokens.COMMA
            push!(args1, PUNCTUATION(next(ps)))
        end
        if ps.ws.kind == SemiColonWS
            parse_parameters(ps, args1)
        end
    end
    if !isempty(args1)
        paras = EXPR{Parameters}(args1)
        push!(args, paras)
    end
    return
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    at = PUNCTUATION(ps)
    if !isemptyws(ps.ws)
        #TODO: error code
        return EXPR{ERROR}(Any[INSTANCE(ps)], 0, 0:-1)
    end
    mname = EXPR{MacroName}(Any[at, IDENTIFIER(next(ps))])

    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isemptyws(ps.ws)
        while ps.nt.kind == Tokens.DOT
            op = OPERATOR(next(ps))
            if ps.nt.kind != Tokens.IDENTIFIER
                return EXPR{ERROR}(Any[])
            end
            nextarg = IDENTIFIER(next(ps))
            mname = BinarySyntaxOpCall(mname, op, Quotenode(nextarg))
        end
    end

    if ps.nt.kind == Tokens.COMMA
        return EXPR{MacroCall}(Any[mname])
    elseif isemptyws(ps.ws) && ps.nt.kind == Tokens.LPAREN
        return parse_call(ps, mname)
    else
        args = Any[mname]
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            @catcherror ps a = @closer ps inmacro @closer ps ws @closer ps wsop parse_expression(ps)
            push!(args, a)
            if insquare && ps.nt.kind == Tokens.FOR
                break
            end
        end
        return EXPR{MacroCall}(args)
    end
end




"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, @nospecialize ret)
    kw = KEYWORD(next(ps))
    ret = EXPR{Generator}(Any[ret, kw])
    @catcherror ps ranges = @closer ps square parse_ranges(ps)

    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR{Filter}(ranges.args)
        else
            ranges = EXPR{Filter}(Any[ranges])
        end
        pushfirst!(ranges, KEYWORD(next(ps)))
        @catcherror ps cond = @closer ps range parse_expression(ps)
        pushfirst!(ranges, cond)
        push!(ret, ranges)
    elseif ranges isa EXPR{Block}
        append!(ret, ranges)
    else
        push!(ret, ranges)
    end
    

    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}(Any[ret])
    end

    return ret
end



function parse_dot_mod(ps::ParseState, is_colon = false)
    args = Any[]

    while ps.nt.kind == Tokens.DOT || ps.nt.kind == Tokens.DDOT || ps.nt.kind == Tokens.DDDOT
        d = OPERATOR(next(ps))
        if is_dot(d)
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
        elseif is_ddot(d)
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
        elseif is_dddot(d)
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
            push!(args, OPERATOR(1, 1:1, Tokens.DOT, false))
        end
    end

    # import/export ..
    if ps.nt.kind == Tokens.COMMA || ps.ws.kind == NewLineWS || ps.nt.kind == Tokens.ENDMARKER
        if length(args) == 2
            return Any[INSTANCE(ps)]
        end
    end

    while true
        if ps.nt.kind == Tokens.AT_SIGN
            at = PUNCTUATION(next(ps))
            a = INSTANCE(next(ps))
            push!(args, EXPR{MacroName}(Any[at, a]))
        elseif ps.nt.kind == Tokens.LPAREN
            a = EXPR{InvisBrackets}(Any[PUNCTUATION(next(ps))])
            @catcherror ps push!(a, parse_expression(ps))
            push!(a, PUNCTUATION(next(ps)))
            push!(args, a)
        elseif ps.nt.kind == Tokens.EX_OR
            @catcherror ps a = @closer ps comma parse_expression(ps)
            push!(args, a)
        elseif !is_colon && isoperator(ps.nt)
            next(ps)
            push!(args, OPERATOR(ps.nt.startbyte - ps.t.startbyte - 1, broadcast(+, 1, (0:ps.t.endbyte - ps.t.startbyte)), ps.t.kind, false))
        else
            push!(args, INSTANCE(next(ps)))
        end

        if ps.nt.kind == Tokens.DOT
            push!(args, PUNCTUATION(next(ps)))
        elseif isoperator(ps.nt) && ps.nt.kind == Tokens.DOT
            push!(args, PUNCTUATION(Tokens.DOT, 1, 1:1))
        elseif isoperator(ps.nt) && ps.nt.dotop
            push!(args, PUNCTUATION(Tokens.DOT, 1, 1:1))
            ps.nt = RawToken(ps.nt.kind, ps.nt.startpos, ps.nt.endpos, ps.nt.startbyte + 1, ps.nt.endbyte, ps.nt.token_error, false)
        else
            break
        end
    end
    args
end
