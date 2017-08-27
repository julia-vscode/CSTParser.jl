function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    kw = INSTANCE(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        sig = INSTANCE(ps)
        @catcherror ps sig = parse_call(ps, sig)
    else
        @catcherror ps sig = @closer ps ws parse_expression(ps)
    end

    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    ret = EXPR{Macro}(Any[kw, sig, EXPR{Block}(blockargs), INSTANCE(next(ps))])
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
    args = Any[mname]

    if ps.nt.kind == Tokens.COMMA
        return EXPR{MacroCall}(args)
    end
    if isemptyws(ps.ws) && ps.nt.kind == Tokens.LPAREN
        push!(args, INSTANCE(next(ps)))
        @catcherror ps @default ps @nocloser ps newline @closer ps paren parse_comma_sep(ps, args, false)
        
        push!(args, INSTANCE(next(ps)))
    else
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            @catcherror ps a = @closer ps inmacro @closer ps ws @closer ps wsop parse_expression(ps)
            push!(args, a)
            if insquare && ps.nt.kind == Tokens.FOR
                break
            end
        end
    end
    return EXPR{MacroCall}(args)
end
