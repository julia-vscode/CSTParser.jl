function parse_kw(ps::ParseState, ::Type{Val{Tokens.TRY}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    ret = EXPR{Try}(EXPR[kw], -ps.t.startbyte, Variable[], "")

    tryblock = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps @closer ps trycatch parse_block(ps, tryblock, start_col)
    push!(ret.args, tryblock)
    
    # try closing early
    if ps.nt.kind == Tokens.END
        next(ps)
        push!(ret.args, FALSE)
        push!(ret.args, EXPR{Block}(EXPR[], 0, Variable[], ""))
        push!(ret.args, INSTANCE(ps))
        ret.span += ps.nt.startbyte
        return ret
    end

    #  catch block
    if ps.nt.kind == Tokens.CATCH
        next(ps)
        # catch closing early
        if ps.nt.kind == Tokens.FINALLY || ps.nt.kind == Tokens.END
            push!(ret.args, INSTANCE(ps))
            caught = FALSE
            catchblock = EXPR{Block}(EXPR[], 0, Variable[], "")
        else
            start1 = ps.nt.startbyte
            start_col = ps.t.startpos[2] + 4
            push!(ret.args, INSTANCE(ps))
            if ps.ws.kind == SemiColonWS || ps.ws.kind == NewLineWS
                caught = FALSE
            else
                @catcherror ps startbyte caught = @default ps @closer ps ws @closer ps trycatch parse_expression(ps)
            end
            catchblock = EXPR{Block}(EXPR[], 0, Variable[], "")
            @catcherror ps startbyte @default ps @closer ps trycatch parse_block(ps, catchblock, start_col)
            if !(caught isa EXPR{IDENTIFIER} || caught == FALSE)
                unshift!(catchblock.args, caught)
                catchblock.span += caught.span
                caught = FALSE
            elseif caught isa EXPR{IDENTIFIER}
                push!(caught.defs, Variable(Expr(caught), :Any, caught))
            end
        end
    else
        caught = FALSE
        catchblock = EXPR{Block}(EXPR[], 0, Variable[], "")
    end
    push!(ret.args, caught)
    push!(ret.args, catchblock)
    
    # finally block
    if ps.nt.kind == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[4] = FALSE
        end
        next(ps)
        start_col = ps.t.startpos[2] + 4
        push!(ret.args, INSTANCE(ps))
        finallyblock = EXPR{Block}(EXPR[], 0, Variable[], "")
        @catcherror ps startbyte parse_block(ps, finallyblock, start_col)
        push!(ret.args, finallyblock)
    end

    next(ps)
    push!(ret.args, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    return ret
end
