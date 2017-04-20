function parse_kw(ps::ParseState, ::Type{Val{Tokens.TRY}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    ret = EXPR(kw, [], -ps.t.startbyte)

    @catcherror ps startbyte tryblock = @default ps @closer ps trycatch parse_block(ps, start_col)
    push!(ret.args, tryblock)
    
    # try closing early
    if ps.nt.kind == Tokens.END
        next(ps)
        push!(ret.args, FALSE)
        push!(ret.args, EXPR(BLOCK, SyntaxNode[]))
        push!(ret.punctuation, INSTANCE(ps))
        ret.span += ps.nt.startbyte
        return ret
    end

    #  catch block
    if ps.nt.kind == Tokens.CATCH
        next(ps)
        # catch closing early
        if ps.nt.kind == Tokens.FINALLY || ps.nt.kind == Tokens.END
            push!(ret.punctuation, INSTANCE(ps))
            caught = FALSE
            catchblock = EXPR(BLOCK, SyntaxNode[])
        else
            start1 = ps.nt.startbyte
            start_col = ps.t.startpos[2] + 4
            push!(ret.punctuation, INSTANCE(ps))
            if ps.ws.kind == SemiColonWS || ps.ws.kind == NewLineWS
                caught = FALSE
            else
                @catcherror ps startbyte caught = @default ps @closer ps ws @closer ps trycatch parse_expression(ps)
            end
            @catcherror ps startbyte catchblock = @default ps @closer ps trycatch parse_block(ps, start_col)
            if !(caught isa IDENTIFIER || caught == FALSE)
                unshift!(catchblock.args, caught)
                catchblock.span += caught.span
                caught = FALSE
            end
        end
    else
        caught = FALSE
        catchblock = EXPR(BLOCK, SyntaxNode[])
    end
    push!(ret.args, caught)
    push!(ret.args, catchblock)
    
    # finally block
    if ps.nt.kind == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[3] = FALSE
        end
        next(ps)
        start_col = ps.t.startpos[2] + 4
        push!(ret.punctuation, INSTANCE(ps))
        @catcherror ps startbyte finallyblock = parse_block(ps, start_col)
        push!(ret.args, finallyblock)
    end

    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    return ret
end


function _start_try(x::EXPR)
    if length(x.punctuation) == 1
        return Iterator{:try}(1, 3)
    elseif length(x.punctuation) == 2
        if x.args[2] == FALSE
            return Iterator{:try}(1, 5)
        else
            return Iterator{:try}(1, 6)
        end
    elseif length(x.punctuation) == 3
        if x.args[2] == FALSE
            return Iterator{:try}(1, 7)
        else
            return Iterator{:try}(1, 8)
        end
    end
end

function next(x::EXPR, s::Iterator{:try})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    elseif s.i == 3
        return first(x.punctuation), +s
    elseif s.i == 4
        if x.args[2] != FALSE
            return x.args[2], +s
        elseif x.punctuation[1] isa KEYWORD{Tokens.FINALLY}
            return x.args[4], +s
        else
            return x.args[3], +s
        end
    elseif s.i == 5
        if x.args[2] != FALSE
            return x.args[3], +s
        else
            return x.punctuation[2], +s
        end
    elseif s.i == 6
        if x.args[2] != FALSE
            return x.punctuation[2], +s
        else
            return x.args[4], +s
        end
    elseif s.i == 7
        return x.args[4], +s
    end
end
