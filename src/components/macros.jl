function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    start_col = ps.t.startpos[2] + 4
    kw = INSTANCE(ps)
    format_kw(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        sig = INSTANCE(ps)
        @catcherror ps sig = parse_call(ps, sig)
    else
        @catcherror ps sig = @closer ps block @closer ps ws parse_expression(ps)
    end

    _get_sig_defs!(sig)
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, block, start_col)

    next(ps)
    ret = EXPR{Macro}(EXPR[kw, sig, block, INSTANCE(ps)], Variable[], "")
    ret.defs =  [Variable(Symbol("@", Expr(_get_fname(sig))), :Macro, ret)]
    return ret
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    next(ps)
    mname = EXPR{IDENTIFIER}(EXPR[], Variable[], string("@", ps.t.val))
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
        return ret
    end
    if isemptyws(ps.ws) && ps.nt.kind == Tokens.LPAREN
        next(ps)
        push!(ret, INSTANCE(ps))
        @catcherror ps @default ps @nocloser ps newline @closer ps paren parse_comma_sep(ps, ret, false)
        next(ps)
        push!(ret, INSTANCE(ps))
    else
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            @catcherror ps a = @closer ps inmacro @closer ps ws @closer ps wsop parse_expression(ps)
            push!(ret, a)
            if insquare && ps.nt.kind == Tokens.FOR
                break
            end
        end
    end
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


