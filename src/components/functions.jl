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
function parse_call_exor(ps::ParseState, ret::ANY)
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call_decl(ps::ParseState, ret::ANY)
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call_and(ps::ParseState, ret::ANY)
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end

# NEEDS FIX: these are broken (i.e. `<:(a,b) where T = 1`)
function parse_call_issubt(ps::ParseState, ret::ANY)
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call_issupt(ps::ParseState, ret::ANY)
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call_PlusOp(ps::ParseState, ret::ANY)
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

function parse_call(ps::ParseState, ret::ANY)
    if is_plus(ret) || is_minus(ret) || is_not(ret)
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



# NEEDS FIX
_arg_id(x) = x
_arg_id(x::IDENTIFIER) = x
_arg_id(x::EXPR{Quotenode}) = x.args[1]
_arg_id(x::EXPR{Curly}) = _arg_id(x.args[1])
_arg_id(x::EXPR{Kw}) = _arg_id(x.args[1])


function _arg_id(x::UnarySyntaxOpCall)
    if is_dddot(x.arg2)
        return _arg_id(x.arg1)
    else
        return x
    end
end

function _arg_id(x::BinarySyntaxOpCall)
    if is_decl(x.op)
        return _arg_id(x.arg1)
    else
        return x
    end
end
function _arg_id(x::WhereOpCall)
    return _arg_id(x.arg1)
end


_get_fparams(x, args = Symbol[]) = args

function _get_fparams(x::EXPR{Call}, args = Symbol[])
    if x.args[1] isa EXPR{Curly}
        _get_fparams(x.args[1], args)
    end
    unique(args)
end

function _get_fparams(x::EXPR{Curly}, args = Symbol[])
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa IDENTIFIER
                push!(args, Expr(a))
            elseif a isa BinarySyntaxOpCall && is_issubt(a.op)
                push!(args, Expr(a).args[1])
            end
        end
    end
    unique(args)
end

function _get_fparams(x::WhereOpCall, args = Symbol[])
    if x.arg1 isa WhereOpCall
        _get_fparams(x.arg1, args)
    end
    for i = 1:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa IDENTIFIER
                push!(args, Expr(a))
            elseif a isa BinarySyntaxOpCall && is_issubt(a.op) && a.arg1 isa IDENTIFIER
                push!(args, Expr(a.arg1))
            end
        end
    end
    return unique(args)
end


_get_fname(sig::EXPR{FunctionDef}) = _get_fname(sig.args[2])
_get_fname(sig::IDENTIFIER) = sig
_get_fname(sig::EXPR{TupleH}) = NOTHING
function _get_fname(sig::WhereOpCall)
    return _get_fname(sig.arg1)
end
_get_fname(sig::BinaryOpCall) = sig.op
function _get_fname(sig::BinarySyntaxOpCall)
    if is_decl(sig.op)
        return _get_fname(sig.arg1)
    else
        return get_id(sig.arg1)
    end
end
_get_fname(sig) = get_id(sig.args[1])
_get_fname(sig::UnaryOpCall) = sig.op
_get_fname(sig::UnarySyntaxOpCall) = sig.arg1 isa OPERATOR ? sig.arg1 : sig.arg2

_get_fsig(fdecl::EXPR{FunctionDef}) = fdecl.args[2]
_get_fsig(fdecl::BinarySyntaxOpCall) = fdecl.arg1


declares_function(x) = false
declares_function(x::EXPR{FunctionDef}) = true
function declares_function(x::BinarySyntaxOpCall)
    if is_eq(x.op)
        sig = x.arg1
        while true
            if sig isa EXPR{Call}
                return true
            elseif sig isa BinarySyntaxOpCall && is_decl(sig.op) || sig isa WhereOpCall
                sig = sig.arg1
            else
                return false
            end
        end
    end
    return false
end
