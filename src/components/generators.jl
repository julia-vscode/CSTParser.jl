"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    start = ps.nt.startbyte
    
    @assert !isempty(ps.ws)
    next(ps)
    op = INSTANCE(ps)
    range = @clear ps @closer ps paren @closer ps square parse_expression(ps)

    ret = EXPR(GENERATOR, [ret, range], ret.span + ps.nt.startbyte - start, [op])
    return ret
end

function _start_generator(x::EXPR)
    return Iterator{:generator}(1, 3)
end

function next(x::EXPR, s::Iterator{:generator})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2 
        return x.punctuation[1], +s
    else
        return x.args[s.i-1], +s
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