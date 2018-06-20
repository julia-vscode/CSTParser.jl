function parse_macro(ps::ParseState)
    kw = KEYWORD(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        sig = IDENTIFIER(next(ps))
        @catcherror ps sig = parse_call(ps, sig)
    else
        @catcherror ps sig = @closer ps ws parse_expression(ps)
    end

    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    return EXPR{Macro}(Any[kw, sig, EXPR{Block}(blockargs), KEYWORD(next(ps))])
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
