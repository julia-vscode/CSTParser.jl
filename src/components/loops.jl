function parse_for(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps ranges = @default ps parse_ranges(ps)
    
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    return EXPR(For, Any[kw, ranges, EXPR(Block, blockargs), KEYWORD(next(ps))])
end


function parse_ranges(ps::ParseState)
    arg = @closer ps range @closer ps ws parse_expression(ps)

    if !is_range(arg)
        ps.errored = true
        return EXPR(ERROR, Any[])
    end
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR(Block, Any[arg])
        while ps.nt.kind == Tokens.COMMA
            push!(arg, PUNCTUATION(next(ps)))

            @catcherror ps nextarg = @closer ps comma @closer ps ws parse_expression(ps)
            if !is_range(nextarg)
                ps.errored = true
                return EXPR(ERROR, Any[])
            end
            push!(arg, nextarg)
        end
    end
    return arg
end


function is_range(x) false end
function is_range(x::BinarySyntaxOpCall)
    if is_eq(x.op)
        return true
    else
        return false
    end
end

function is_range(x::BinaryOpCall)
    if is_in(x.op) || is_elof(x.op)
        return true
    else
        return false
    end
end



function parse_while(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps cond = @default ps @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    return EXPR(While, Any[kw, cond, EXPR(Block, blockargs), KEYWORD(next(ps))])
end




"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    kw = KEYWORD(next(ps))
    ret = EXPR(Generator, Any[ret, kw])
    @catcherror ps ranges = @closer ps paren @closer ps square parse_ranges(ps)

    if ps.nt.kind == Tokens.IF
        if is_block(ranges)
            ranges = EXPR(Filter, ranges.args)
        else
            ranges = EXPR(Filter, Any[ranges])
        end
        unshift!(ranges, KEYWORD(next(ps)))
        @catcherror ps cond = @closer ps range @closer ps paren parse_expression(ps)
        unshift!(ranges, cond)
        push!(ret, ranges)
    else
        if is_block(ranges)
            append!(ret, ranges)
        else
            push!(ret, ranges)
        end
    end

    if is_generator(ret.args[1]) || is_flatten(ret.args[1])
        ret = EXPR(Flatten, Any[ret])
    end

    return ret
end
