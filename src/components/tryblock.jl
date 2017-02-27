parse_kw(ps::ParseState, ::Type{Val{Tokens.TRY}}) = parse_try(ps)

# function parse_try(ps::ParseState)
#     start = ps.t.startbyte
#     kw = INSTANCE(ps)
#     tryblock = EXPR(BLOCK, Expression[], -ps.nt.startbyte)
#     while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.CATCH 
#         push!(tryblock.args, @closer ps trycatch parse_expression(ps))
#     end
#     tryblock.span += ps.nt.startbyte 
#     if ps.nt.kind == Tokens.END
#         next(ps)
#         return EXPR(kw, Expression[tryblock, FALSE, EXPR(BLOCK, Expression[], 0)], ps.nt.startbyte - start, [INSTANCE(ps)])
#     end

#     puncs = INSTANCE[]
#     next(ps)
#     if ps.t.kind==Tokens.CATCH
#         start_col = ps.t.startpos[2]
#         push!(puncs, INSTANCE(ps))
#         caught = parse_expression(ps)
#         catchblock = @closer ps trycatch parse_block(ps, start_col)
#         if !(caught isa INSTANCE)
#             unshift!(catchblock.args, caught)
#             caught = FALSE
#         end
#     else
#         caught = FALSE
#         catchblock = EXPR(BLOCK, Expression[], 0)
#     end
#     next(ps)
#     if ps.t.kind == Tokens.FINALLY
#         push!(puncs, INSTANCE(ps))
#         finallyblock = parse_block(ps)
#     end

#     push!(puncs, INSTANCE(ps))
#     return EXPR(kw, Expression[tryblock, caught ,catchblock], ps.nt.startbyte - start, puncs)
# end


function parse_try(ps::ParseState)
    start_col = ps.t.startpos[2]
    kw = INSTANCE(ps)
    ret = EXPR(kw, [EXPR(BLOCK, Expression[], -ps.nt.startbyte)], -ps.t.startbyte)

    @closer ps trycatch parse_block(ps, start_col, ret.args[1])
    
    # If closing early
    if ps.nt.kind == Tokens.END
        next(ps)
        push!(ret.args, FALSE)
        push!(ret.args, EXPR(BLOCK, Expression[]))
        push!(ret.punctuation, INSTANCE(ps))
        ret.span += ps.nt.startbyte
        return ret
    end

    
    #  Catch block
    if ps.nt.kind==Tokens.CATCH
        next(ps)
        start_col = ps.t.startpos[2]
        push!(ret.punctuation, INSTANCE(ps))
        caught = parse_expression(ps)
        catchblock = @closer ps trycatch parse_block(ps, start_col)
        if !(caught isa INSTANCE)
            unshift!(catchblock.args, caught)
            catchblock.span = caught.span
            caught = FALSE
        end
    else
        caught = FALSE
        catchblock = EXPR(BLOCK, Expression[])
    end
    push!(ret.args, caught)
    push!(ret.args, catchblock)
    
    # Finally block
    if ps.nt.kind == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[3] = FALSE
        end
        next(ps)
        start_col = ps.t.startpos[2]
        push!(ret.punctuation, INSTANCE(ps))
        finallyblock = EXPR(BLOCK, [])
        parse_block(ps, start_col, finallyblock)
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
        if x.args[2]==FALSE
            return Iterator{:try}(1, 5)
        else
            return Iterator{:try}(1, 6)
        end
    elseif length(x.punctuation) == 3
        if x.args[2]==FALSE
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
        # elseif length(x.args) == 4 && s.n == 5
        #     return x.args[4], +s
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
