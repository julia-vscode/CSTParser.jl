function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4
    kw = INSTANCE(ps)
    format_kw(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        sig = INSTANCE(ps)
        @catcherror ps startbyte sig = parse_call(ps, sig)
    else
        @catcherror ps startbyte sig = @closer ps block @closer ps ws parse_expression(ps)
    end
    _lint_func_sig(ps, sig, ps.nt.startbyte + (-sig.span:0))
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)

    next(ps)
    ret = EXPR{Macro}(EXPR[kw, sig, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
    ret.defs =  [Variable(Symbol("@", Expr(_get_fname(sig))), :Macro, ret)]
    return ret
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    startbyte = ps.t.startbyte
    next(ps)
    mname = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.lt.startbyte, Variable[], string("@", ps.t.val))
    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isemptyws(ps.ws)
        while ps.nt.kind == Tokens.DOT
            next(ps)
            op = INSTANCE(ps)
            if ps.nt.kind != Tokens.IDENTIFIER
                return EXPR{ERROR}(EXPR[], 0, Variable[], "Invalid macro name")
            end
            next(ps)
            nextarg = INSTANCE(ps)
            mname = EXPR{BinarySyntaxOpCall}(EXPR[mname, op, Quotenode(nextarg)], mname.span + op.span + nextarg.span, Variable[], "")
        end
    end
    ret = EXPR{MacroCall}(EXPR[mname], 0, Variable[], "")

    if ps.nt.kind == Tokens.COMMA
        ret.span = ps.nt.startbyte - startbyte
        return ret
    end
    if isemptyws(ps.ws) && ps.nt.kind == Tokens.LPAREN
        next(ps)
        push!(ret.args, INSTANCE(ps))
        @catcherror ps startbyte args = @default ps @nocloser ps newline @closer ps paren parse_list(ps, ret.args)
        append!(ret.args, args)
        next(ps)
        push!(ret.args, INSTANCE(ps))
    else
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            @catcherror ps startbyte a = @closer ps inmacro @closer ps ws @closer ps wsop parse_expression(ps)
            push!(ret.args, a)
            if insquare && ps.nt.kind == Tokens.FOR
                break
            end
        end
    end
    ret.span = ps.nt.startbyte - startbyte
    return ret
end


ismacro(x) = false
ismacro(x::EXPR{LITERAL{Tokens.MACRO}}) = true
ismacro(x::EXPR{Quotenode}) = ismacro(x.args[1])
function ismacro(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa OPERATOR{DotOp,Tokens.DOT}
        return ismacro(x.args[2])
    else
        return false
    end
end


