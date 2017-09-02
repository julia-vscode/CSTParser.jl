function parse_function(ps::ParseState)
    kw = KEYWORD(ps)
    if isoperator(ps.nt.kind) && ps.nt.kind != Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        next(ps)
        op = OPERATOR(ps)
        next(ps)
        args = Any[op, INSTANCE(ps)]
        @catcherror ps @default ps @closer ps paren parse_comma_sep(ps, args)
        push!(args, INSTANCE(next(ps)))
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
        if sig isa EXPR{Call} || (sig isa WhereOpCall || (sig isa BinarySyntaxOpCall && !(sig.arg1 isa OPERATOR{Tokens.EX_OR,false})))
            args = Any[sig, EXPR{Block}(blockargs)]
        else
            args = Any[sig]
        end
    else
        args = Any[sig, EXPR{Block}(blockargs)]
    end

    next(ps)

    ret = EXPR{FunctionDef}(Any[kw])
    for a in args
        push!(ret, a)
    end
    push!(ret, KEYWORD(ps))
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret::OPERATOR{Tokens.EX_OR,false})
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call(ps::ParseState, ret::OPERATOR{Tokens.DECLARATION,false})
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call(ps::ParseState, ret::OPERATOR{Tokens.AND})
    arg = @precedence ps 20 parse_expression(ps)
    ret = UnarySyntaxOpCall(ret, arg)
    return ret
end
function parse_call(ps::ParseState, ret::OPERATOR{Tokens.ISSUBTYPE,false})
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call(ps::ParseState, ret::OPERATOR{Tokens.ISSUPERTYPE,false})
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(Any[ret; arg.args])
    return ret
end

function parse_call(ps::ParseState, ret::OPERATOR{Tokens.NOT})
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(Any[ret; arg.args])
    else
        ret = UnaryOpCall(ret, arg)
    end
    return ret
end

function parse_call(ps::ParseState, ret::OPERATOR{Tokens.PLUS})
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(Any[ret; arg.args])
    else
        ret = UnaryOpCall(ret, arg)
    end
    return ret
end

function parse_call(ps::ParseState, ret::OPERATOR{Tokens.MINUS})
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(Any[ret; arg.args])
    else
        ret = UnaryOpCall(ret, arg)
    end
    return ret
end

function parse_call(ps::ParseState, ret)
    args = Any[ret, INSTANCE(next(ps))]
    @default ps @closer ps paren parse_comma_sep(ps, args)
    push!(args, INSTANCE(next(ps)))
    return EXPR{Call}(args)
end


function parse_comma_sep(ps::ParseState, args::Vector{Any}, kw = true, block = false, istuple = false)
    @catcherror ps @nocloser ps inwhere @nocloser ps newline @closer ps comma while !closer(ps)
        a = parse_expression(ps)

        if kw && !ps.closer.brace && a isa BinarySyntaxOpCall && a.op isa OPERATOR{Tokens.EQ,false}
            a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
        end
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(args, INSTANCE(ps))
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
                if kw && !ps.closer.brace && a isa BinarySyntaxOpCall && a.op isa OPERATOR{Tokens.EQ,false}
                    a = EXPR{Kw}(Any[a.arg1, a.op, a.arg2])
                end
                # push!(paras, a)
                push!(args1, a)
                if ps.nt.kind == Tokens.COMMA
                    next(ps)
                    # push!(paras, INSTANCE(ps))
                    push!(args1, INSTANCE(ps))
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
_arg_id(x::EXPR{Quotenode}) = x.val
_arg_id(x::EXPR{Curly}) = _arg_id(x.args[1])
_arg_id(x::EXPR{Kw}) = _arg_id(x.args[1])


function _arg_id(x::UnarySyntaxOpCall)
    if x.args[2] isa OPERATOR{Tokens.DDDOT,false}
        return _arg_id(x.args[1])
    else
        return x
    end
end

function _arg_id(x::BinarySyntaxOpCall)
    if x.op isa OPERATOR{Tokens.DECLARATION,false}
        return _arg_id(x.arg1)
    else
        return x
    end
end
function _arg_id(x::WhereOpCall)
    return _arg_id(x.arg1)
end


_get_fparams(x::EXPR, args = Symbol[]) = args

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
            elseif a isa BinarySyntaxOpCall && a.op isa OPERATOR{Tokens.ISSUBTYPE,false}
                push!(args, Expr(a).args[1])
            end
        end
    end
    unique(args)
end

function _get_fparams(x::WhereOpCall, args = Symbol[])
    if x.args[1] isa WhereOpCall
        _get_fparams(x.arg1, args)
    end
    for i = 1:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa IDENTIFIER
                push!(args, Expr(a))
            elseif a isa BinarySyntaxOpCall && a.op isa OPERATOR{Tokens.ISSUBTYPE,false} && a.arg1 isa IDENTIFIER
                push!(args, Expr(a.args[1]))
            end
        end
    end
    return unique(args)
end


_get_fname(sig::EXPR{FunctionDef}) = _get_fname(sig.args[2])
_get_fname(sig::IDENTIFIER) = sig
_get_fname(sig::EXPR{Tuple}) = NOTHING
function _get_fname(sig::WhereOpCall)
    return _get_fname(sig.arg1)
end
function _get_fname(sig::BinarySyntaxOpCall)
    if sig.op isa OPERATOR{Tokens.DECLARATION,false}
        return _get_fname(sig.args[1])
    else
        return get_id(sig.args[1])
    end
end
_get_fname(sig) = get_id(sig.args[1])

_get_fsig(fdecl::EXPR{FunctionDef}) = fdecl.args[2]
_get_fsig(fdecl::BinarySyntaxOpCall) = fdecl.arg1


declares_function(x) = false
declares_function(x::EXPR{FunctionDef}) = true
function declares_function(x::BinarySyntaxOpCall)
    if x.op isa OPERATOR{Tokens.EQ,false}
        sig = x.args[1]
        while true
            if sig isa EXPR{Call}
                return true
            elseif sig isa BinarySyntaxOpCall && sig.op isa OPERATOR{Tokens.DECLARATION,false} || sig isa WhereOpCall
                sig = sig.args[1]
            else
                return false
            end
        end
    end
    return false
end
