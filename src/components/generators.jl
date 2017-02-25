"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    ret = EXPR(GENERATOR,[ret], ret.span - ps.nt.startbyte)
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ranges = @closer ps paren @closer ps square parse_ranges(ps)
    if ranges isa EXPR && ranges.head == BLOCK
        append!(ret.args, ranges.args)
        append!(ret.punctuation, ranges.punctuation)
    else
        push!(ret.args, ranges)
    end
    ret.span += ps.nt.startbyte
    return ret
end

function _start_generator(x::EXPR)
    return Iterator{:generator}(1, length(x.args)*2 - 1)
end

function next(x::EXPR, s::Iterator{:generator})
    # if s.i == 1
    #     return x.args[1], +s
    # elseif s.i == 2 
    #     return x.punctuation[1], +s
    # else
    #     return x.args[s.i-1], +s
    # end
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function _start_comprehension(x::EXPR)
    return Iterator{:comprehension}(1, 3)
end

function next(x::EXPR, s::Iterator{:comprehension})
    if s.i == 1
        return x.punctuation[1], +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3 
        return x.punctuation[2], +s
    end
end

function _start_typed_comprehension(x::EXPR)
    return Iterator{:typed_comprehension}(1, 4)
end

function next(x::EXPR, s::Iterator{:typed_comprehension})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return x.punctuation[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4 
        return x.punctuation[2], +s
    end
end