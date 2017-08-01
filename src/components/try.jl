function parse_kw(ps::ParseState, ::Type{Val{Tokens.TRY}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    ret = EXPR{Try}(EXPR[kw], Variable[], "")

    tryblock = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
    @catcherror ps @default ps @closer ps trycatch parse_block(ps, tryblock,)
    push!(ret, tryblock)

    # try closing early
    if ps.nt.kind == Tokens.END
        next(ps)
        push!(ret, FALSE)
        push!(ret, EXPR{Block}(EXPR[], 0, 1:0, Variable[], ""))
        push!(ret, INSTANCE(ps))
        return ret
    end

    #  catch block
    if ps.nt.kind == Tokens.CATCH
        next(ps)
        # catch closing early
        if ps.nt.kind == Tokens.FINALLY || ps.nt.kind == Tokens.END
            push!(ret, INSTANCE(ps))
            caught = FALSE
            catchblock = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
        else
            start_col = ps.t.startpos[2] + 4
            push!(ret, INSTANCE(ps))
            if ps.ws.kind == SemiColonWS || ps.ws.kind == NewLineWS
                caught = FALSE
            else
                @catcherror ps caught = @default ps @closer ps ws @closer ps trycatch parse_expression(ps)
            end
            catchblock = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
            @catcherror ps @default ps @closer ps trycatch parse_block(ps, catchblock)
            if !(caught isa EXPR{IDENTIFIER} || caught == FALSE)
                unshift!(catchblock, caught)
                caught = FALSE
            elseif caught isa EXPR{IDENTIFIER}
                push!(caught.defs, Variable(Expr(caught), :Any, caught))
            end
        end
    else
        caught = FALSE
        catchblock = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
    end
    push!(ret, caught)
    push!(ret, catchblock)

    # finally block
    if ps.nt.kind == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[4] = FALSE
        end
        next(ps)
        push!(ret, INSTANCE(ps))
        finallyblock = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
        @catcherror ps parse_block(ps, finallyblock)
        push!(ret, finallyblock)
    end

    next(ps)
    push!(ret, INSTANCE(ps))
    return ret
end
