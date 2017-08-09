function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    # Parsing
    kw = INSTANCE(ps)
    # signature

    if isoperator(ps.nt.kind) && ps.nt.kind != Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        next(ps)
        op = OPERATOR(ps)
        next(ps)
        if issyntaxunarycall(op)
            sig = EXPR{UnarySyntaxOpCall}(EXPR[op, INSTANCE(ps)], "")
        else
            sig = EXPR{Call}(EXPR[op, INSTANCE(ps)], "")
        end
        @catcherror ps @default ps @closer ps paren parse_comma_sep(ps, sig)
        next(ps)
        push!(sig, INSTANCE(ps))
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
        sig = EXPR{TupleH}(sig.args, "")
    end

    block = EXPR{Block}(EXPR[], 0, 1:0, "")
    @catcherror ps @default ps @scope ps Scope{Tokens.FUNCTION} parse_block(ps, block)


    # Construction
    if isempty(block.args)
        if sig isa EXPR{Call} || sig isa EXPR{BinarySyntaxOpCall} && !(sig.args[1] isa EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}})
            args = EXPR[sig, block]
        else
            args = EXPR[sig]
        end
    else
        args = EXPR[sig, block]
    end

    next(ps)

    ret = EXPR{FunctionDef}(EXPR[kw], "")
    for a in args
        push!(ret, a)
    end
    push!(ret, INSTANCE(ps))
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}})
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}})
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{TimesOp,Tokens.AND}
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}})
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(EXPR[ret; arg.args], "")
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false}})
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(EXPR[ret; arg.args], "")
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{20,Tokens.NOT}
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{PlusOp,Tokens.PLUS}
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{PlusOp,Tokens.MINUS}
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret)
    next(ps)
    ret = EXPR{Call}(EXPR[ret, INSTANCE(ps)], "")
    @default ps @closer ps paren parse_comma_sep(ps, ret)
    next(ps)
    push!(ret, INSTANCE(ps))
    return ret
end


function parse_comma_sep(ps::ParseState, ret::EXPR, kw = true, block = false, formatcomma = true)
    @catcherror ps @nocloser ps inwhere @noscope ps @nocloser ps newline @closer ps comma while !closer(ps)
        block && (ps.trackscope = true)
        a = parse_expression(ps)

        if kw && !ps.closer.brace && a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
            a = EXPR{Kw}(a.args, "")
        end
        push!(ret, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret, INSTANCE(ps))
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        if block && !(ret isa EXPR{TupleH} && length(ret.args) > 2)
            body = EXPR{Block}(EXPR[pop!(ret)], "")
            @nocloser ps newline @closer ps comma while @nocloser ps semicolon !closer(ps)
                @catcherror ps a = parse_expression(ps)
                push!(body, a)
            end
            push!(ret, body)
            return body
        else
            kw = true
            ps.nt.kind == Tokens.RPAREN && return
            paras = EXPR{Parameters}(EXPR[], "")
            @nocloser ps inwhere @nocloser ps newline @nocloser ps semicolon @closer ps comma while !closer(ps)
                @catcherror ps a = parse_expression(ps)
                if kw && !ps.closer.brace && a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
                    a = EXPR{Kw}(a.args, "")
                end
                push!(paras, a)
                if ps.nt.kind == Tokens.COMMA
                    next(ps)
                    push!(paras, INSTANCE(ps))
                end
            end
            push!(ret, paras)
        end
    end
end



# NEEDS FIX
_arg_id(x) = x
_arg_id(x::EXPR{IDENTIFIER}) = x
_arg_id(x::EXPR{Quotenode}) = x.val
_arg_id(x::EXPR{Curly}) = _arg_id(x.args[1])
_arg_id(x::EXPR{Kw}) = _arg_id(x.args[1])


function _arg_id(x::EXPR{UnarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{7,Tokens.DDDOT,false}}
        return _arg_id(x.args[1])
    else
        return x
    end
end

function _arg_id(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        return _arg_id(x.args[1])
    else
        return x
    end
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
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            if a isa EXPR{IDENTIFIER}
                push!(args, Expr(a))
            elseif a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}}
                push!(args, Expr(a).args[1])
            end
        end
    end
    unique(args)
end

function _get_fparams(x::EXPR{BinarySyntaxOpCall}, args = Symbol[])
    if x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        if x.args[1] isa EXPR{BinarySyntaxOpCall} && x.args[1].args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
            _get_fparams(x.args[1], args)
        end
        for i = 3:length(x.args)
            a = x.args[i]
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                if a isa EXPR{IDENTIFIER}
                    push!(args, Expr(a))
                elseif a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}}
                    push!(args, Expr(a).args[1])
                end
            end
        end
    end
    return unique(args)
end


_get_fname(sig::EXPR{FunctionDef}) = _get_fname(sig.args[2])
_get_fname(sig::EXPR{IDENTIFIER}) = sig
_get_fname(sig::EXPR{Tuple}) = NOTHING
function _get_fname(sig::EXPR{BinarySyntaxOpCall})
    if sig.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || sig.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        return _get_fname(sig.args[1])
    else
        return get_id(sig.args[1])
    end
end
_get_fname(sig) = get_id(sig.args[1])

_get_fsig(fdecl::EXPR{FunctionDef}) = fdecl.args[2]
_get_fsig(fdecl::EXPR{BinarySyntaxOpCall}) = fdecl.args[1]


declares_function(x) = false
declares_function(x::EXPR{FunctionDef}) = true
declares_function(x::EXPR{BinarySyntaxOpCall}) = x.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}} && x.args[1] isa EXPR{Call}
