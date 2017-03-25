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
    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR && ranges.head == BLOCK
            ranges = EXPR(FILTER, [ranges.args...], ranges.span, ranges.punctuation)
        else
            ranges = EXPR(FILTER, [ranges], ranges.span)
        end
        next(ps)
        unshift!(ranges.punctuation, INSTANCE(ps))
        cond = @closer ps paren parse_expression(ps)
        unshift!(ranges.args, cond)
        ranges.span = sum(a.span for a in ranges.args) + sum(a.span for a in ranges.punctuation)
        push!(ret.args, ranges)
    else
        if ranges isa EXPR && ranges.head == BLOCK
            append!(ret.args, ranges.args)
            append!(ret.punctuation, ranges.punctuation)
        else
            push!(ret.args, ranges)
        end
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

function _start_filter(x::EXPR)
    return Iterator{:filter}(1, length(x.args) + length(x.punctuation))
end

function next(x::EXPR, s::Iterator{:filter})
    if s.i == s.n
        return first(x.args), +s
    elseif s.i == s.n - 1
        return first(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i + 1, 2) + 1], +s
    else
        return x.punctuation[div(s.i, 2) + 1], +s
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