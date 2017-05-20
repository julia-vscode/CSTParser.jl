"""
    parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator. 
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    startbyte = ps.nt.startbyte
    ret = EXPR(Generator, SyntaxNode[ret], ret.span - startbyte)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    @catcherror ps startbyte ranges = @closer ps paren @closer ps square parse_ranges(ps)
    
    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR(Filter, SyntaxNode[ranges.args...], ranges.span)
        else
            ranges = EXPR(Filter, SyntaxNode[ranges], ranges.span)
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
    # if ranges isa EXPR && ranges.head == BLOCK
    #     for r in ranges.args
    #         _lint_range(ps, r, startbyte + first(ret.punctuation).span + (0:ranges.span))
    #     end
    # else
    #     _lint_range(ps, ranges, startbyte + first(ret.punctuation).span + (0:ranges.span))
    # end
    # This should reverse order of iterators
    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR(Flatten, [ret], ret.span)
    end

    return ret
end
