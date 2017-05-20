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
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    next(ps)
    ret = EXPR(Macro, SyntaxNode[kw, sig, block, INSTANCE(ps)], ps.nt.startbyte - startbyte)
    # ret.defs =  [Variable(function_name(sig), :Macro, ret)]
    return ret
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    startbyte = ps.t.startbyte
    next(ps)
    mname = IDENTIFIER(ps.nt.startbyte - ps.lt.startbyte, string("@", ps.t.val))
    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isemptyws(ps.ws)
        while ps.nt.kind == Tokens.DOT
            next(ps)
            op = INSTANCE(ps)
            if ps.nt.kind != Tokens.IDENTIFIER
                return ERROR{InvalidMacroName}(startbyte:ps.nt.startbyte, mname)
                
            end
            next(ps)
            nextarg = INSTANCE(ps)
            mname = EXPR(BinarySyntaxOpCall, [mname, op, QUOTENODE(nextarg)], mname.span + op.span + nextarg.span)
        end
    end
    ret = EXPR(MacroCall, [mname], 0)

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
ismacro(x::LITERAL{Tokens.MACRO}) = true
ismacro(x::QUOTENODE) = ismacro(x.val)
function ismacro(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa OPERATOR{DotOp,Tokens.DOT}
        return ismacro(x.args[2])
    else
        return false
    end
end


