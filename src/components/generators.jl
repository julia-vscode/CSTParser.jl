"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    startbyte = ps.nt.startbyte
    next(ps)
    kw = INSTANCE(ps)
    ret = EXPR{Generator}(EXPR[ret, kw], ret.span - startbyte, Variable[], "")
    @catcherror ps startbyte ranges = @closer ps paren @closer ps square parse_ranges(ps)
    
    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR{Filter}(EXPR[ranges.args...], ranges.span, Variable[], "")
        else
            ranges = EXPR{Filter}(EXPR[ranges], ranges.span, Variable[], "")
        end
        next(ps)
        unshift!(ranges.args, INSTANCE(ps))
        @catcherror ps startbyte cond = @closer ps paren parse_expression(ps)
        unshift!(ranges.args, cond)
        ranges.span = sum(a.span for a in ranges.args)
        push!(ret.args, ranges)
    else
        if ranges isa EXPR{Block}
            append!(ret.args, ranges.args)
        else
            push!(ret.args, ranges)
        end
    end
    ret.span += ps.nt.startbyte

    # Linting
    if ranges isa EXPR{Block}
        for r in ranges.args
            _lint_range(ps, r, startbyte + kw.span + (0:ranges.span))
        end
    elseif ranges isa EXPR{Filter}
        for i = 3:length(ranges.args)
            _lint_range(ps, ranges.args[i], startbyte + kw.span + (0:ranges.span))
        end
    else
        _lint_range(ps, ranges, startbyte + kw.span + (0:ranges.span))
    end
    # This should reverse order of iterators
    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}([ret], ret.span, Variable[], "")
    end

    return ret
end
