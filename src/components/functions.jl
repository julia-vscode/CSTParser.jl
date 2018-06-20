function parse_function(ps::ParseState)
    kw = KEYWORD(ps)
    
    @catcherror ps sig = @closer ps inwhere @closer ps block @closer ps ws parse_expression(ps)

    if sig isa EXPR{InvisBrackets} && !(sig.args[2] isa EXPR{TupleH})
        istuple = true
        sig = EXPR{TupleH}(sig.args)
    elseif sig isa EXPR{TupleH}
        istuple = true
    else
        istuple = false
    end

    while ps.nt.kind == Tokens.WHERE && ps.ws.kind != Tokens.NEWLINE_WS
        @catcherror ps sig = @closer ps inwhere @closer ps block @closer ps ws parse_compound(ps, sig)
    end
    
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    if isempty(blockargs)
        if sig isa EXPR{Call} || sig isa WhereOpCall || (sig isa BinarySyntaxOpCall && !(is_exor(sig.arg1))) || istuple
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
    @default ps @closer ps paren parse_comma_sep(ps, args, !ismacro)
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
            kw = true
            ps.nt.kind == Tokens.RPAREN && return args
            args1 = Any[]
            @nocloser ps inwhere @nocloser ps newline @nocloser ps semicolon @closer ps comma while !closer(ps)
                @catcherror ps a = parse_expression(ps)
                if kw && !ps.closer.brace && a isa BinarySyntaxOpCall && is_eq(a.op)
                    a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
                end
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
