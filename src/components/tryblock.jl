parse_kw(ps::ParseState, ::Type{Val{Tokens.TRY}}) = parse_try(ps)

function parse_try(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    tryblock = EXPR(BLOCK, Expression[], -ps.ws.endbyte)
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.CATCH 
        push!(tryblock.args, @closer ps trycatch parse_expression(ps))
    end
    tryblock.span += ps.ws.endbyte 

    puncs = INSTANCE[]
    next(ps)
    if ps.t.kind==Tokens.CATCH
        push!(puncs, INSTANCE(ps))
        caught = parse_expression(ps)
        catchblock = parse_block(ps)
        if !(caught isa INSTANCE)
            unshift!(catchblock.args, caught)
            caught = FALSE
        end
    else
        caught = FALSE
        catchblock = EXPR(BLOCK, Expression[], 0)
    end
    ps.t.kind != Tokens.END && next(ps)
    push!(puncs, INSTANCE(ps))
    return EXPR(kw, Expression[tryblock, caught ,catchblock], ps.nt.startbyte - start, puncs)
end

function _start_try(x::EXPR)
    if isempty(x.args[3].args)
        return Iterator{:try}(1, 3)
    else
        return Iterator{:try}(1, 5 + (x.args[2]!=FALSE))
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
        else
            return x.args[3], +s
        end
    else
        return x.args[3], +s
    end
end
