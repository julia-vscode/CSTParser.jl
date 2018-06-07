function parse_function(ps::ParseState)
    kw = KEYWORD(ps)
    if isoperator(ps.nt.kind) && ps.nt.kind != Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        op = OPERATOR(next(ps))
        args = Any[op, PUNCTUATION(next(ps))] 
        @catcherror ps @default ps @closer ps paren parse_comma_sep(ps, args)
        push!(args, PUNCTUATION(next(ps)))
        sig = EXPR{Call}(args)
        @default ps @closer ps inwhere @closer ps ws @closer ps block while !closer(ps)
            @catcherror ps sig = parse_compound(ps, sig)
        end
    else
        @catcherror ps sig = @default ps @closer ps inwhere @closer ps block @closer ps ws parse_expression(ps)
    end

    while ps.nt.kind == Tokens.WHERE
        @catcherror ps sig = @default ps @closer ps inwhere @closer ps block @closer ps ws parse_compound(ps, sig)
    end

    if sig isa EXPR{InvisBrackets} && !(sig.args[2] isa EXPR{TupleH})
        sig = EXPR{TupleH}(sig.args)
    end

    
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    if isempty(blockargs)
        if sig isa EXPR{Call} || (sig isa WhereOpCall || (sig isa BinarySyntaxOpCall && !(is_exor(sig.arg1))))
            args = Any[sig, EXPR{Block}(blockargs)]
        else
            args = Any[sig]
        end
    else
        args = Any[sig, EXPR{Block}(blockargs)]
    end

    ret = EXPR{FunctionDef}(Any[kw])
    for a in args
        push!(ret, a)
    end
    push!(ret, KEYWORD(next(ps)))
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call_exor(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 20 parse_expression(ps)
    if arg isa EXPR{TupleH} && length(arg.args) == 3 && arg.args[2] isa UnarySyntaxOpCall && arg.args[2].arg2 isa OPERATOR && is_dddot(arg.args[2].arg2)
        arg = EXPR{InvisBrackets}(arg.args)
    end
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call_decl(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call_and(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end

# NEEDS FIX: these are broken (i.e. `<:(a,b) where T = 1`)
function parse_call_issubt(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call_issupt(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call_PlusOp(ps::ParseState, @nospecialize ret)
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(Any[ret; arg.args])
    elseif arg isa WhereOpCall && arg.arg1 isa EXPR{TupleH}
        ret = WhereOpCall(EXPR{Call}(Any[ret; arg.arg1.args]), arg.op, arg.args)
    else
        ret = UnaryOpCall(ret, arg)
    end
    return ret
end

function parse_call(ps::ParseState, @nospecialize ret)
    # if is_plus(ret) || is_minus(ret) || is_not(ret)
    if is_minus(ret) || is_not(ret)
        return parse_call_PlusOp(ps, ret)
    elseif is_and(ret)
        return parse_call_and(ps, ret)
    elseif is_exor(ret)
        return parse_call_exor(ps, ret)
    elseif is_decl(ret)
        return parse_call_decl(ps, ret)
    elseif is_issubt(ret)
        return parse_call_issubt(ps, ret)
    elseif is_issupt(ret)
        return parse_call_issupt(ps, ret)
    end
    args = Any[ret, PUNCTUATION(next(ps))]
    @default ps @closer ps paren parse_comma_sep(ps, args)
    rparen = PUNCTUATION(next(ps))
    rparen.kind == Tokens.RPAREN || return error_unexpected(ps, ps.t)
    push!(args, rparen)
    return EXPR{Call}(args)
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
        if block && !(istuple && length(args) > 2) && !(length(args) == 1 && args[1] isa PUNCTUATION)
            args1 = Any[pop!(args)]
            @nocloser ps newline @closer ps comma while @nocloser ps semicolon !closer(ps)
                @catcherror ps a = parse_expression(ps)
                push!(args1, a)
            end
            body = EXPR{Block}(args1)
            push!(args, body)
            return body
        else
            kw = true
            ps.nt.kind == Tokens.RPAREN && return args
            args1 = Any[]
            @nocloser ps inwhere @nocloser ps newline @nocloser ps semicolon @closer ps comma while !closer(ps)
                @catcherror ps a = parse_expression(ps)
                if kw && !ps.closer.brace && a isa BinarySyntaxOpCall && is_eq(a.op)
                    a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
                end
                # push!(paras, a)
                push!(args1, a)
                if ps.nt.kind == Tokens.COMMA
                    push!(args1, PUNCTUATION(next(ps)))
                end
            end
            paras = EXPR{Parameters}(args1)
            push!(args, paras)
        end
    end
    return args
end
