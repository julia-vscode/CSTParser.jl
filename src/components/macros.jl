function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    kw = INSTANCE(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        sig = INSTANCE(ps)
        @catcherror ps sig = parse_call(ps, sig)
    else
        @catcherror ps sig = @closer ps ws parse_expression(ps)
    end

    block = EXPR{Block}(Any[])
    @catcherror ps @default ps parse_block(ps, block)

    next(ps)
    ret = EXPR{Macro}(Any[kw, sig, block, INSTANCE(ps)])
    return ret
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    at = INSTANCE(ps)
    mname = EXPR{MacroName}(Any[at, IDENTIFIER(next(ps))])

    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isemptyws(ps.ws)
        while ps.nt.kind == Tokens.DOT
            next(ps)
            op = INSTANCE(ps)
            if ps.nt.kind != Tokens.IDENTIFIER
                return EXPR{ERROR}(Any[])
            end
            next(ps)
            nextarg = INSTANCE(ps)
            mname = BinarySyntaxOpCall(mname, op, Quotenode(nextarg))
        end
    end
    ret = EXPR{MacroCall}(Any[mname])

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
