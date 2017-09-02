function parse_for(ps::ParseState)
    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps ranges = @default ps parse_ranges(ps)
    
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    ret = EXPR{For}(Any[kw, ranges, EXPR{Block}(blockargs), INSTANCE(next(ps))])

    return ret
end


function parse_ranges(ps::ParseState)
    arg = @closer ps range @closer ps ws parse_expression(ps)

    if !is_range(arg)
        ps.errored = true
        return EXPR{ERROR}(Any[])
    end
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(Any[arg])
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(arg, INSTANCE(ps))

            @catcherror ps nextarg = @closer ps comma @closer ps ws parse_expression(ps)
            if !is_range(nextarg)
                ps.errored = true
                return EXPR{ERROR}(Any[])
            end
            push!(arg, nextarg)
        end
    end
    return arg
end


function is_range(x) false end
function is_range(x::BinarySyntaxOpCall)
    if x.op isa OPERATOR{Tokens.EQ,false}
        return true
    else
        return false
    end
end

function is_range(x::BinaryOpCall)
    if x.op isa OPERATOR{Tokens.IN,false} || x.op isa OPERATOR{Tokens.ELEMENT_OF,false}
        return true
    else
        return false
    end
end



function parse_while(ps::ParseState)
    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps cond = @default ps @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    ret = EXPR{While}(Any[kw, cond, EXPR{Block}(blockargs), INSTANCE(next(ps))])

    return ret
end




"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    next(ps)
    kw = INSTANCE(ps)
    ret = EXPR{Generator}(Any[ret, kw])
    @catcherror ps ranges = @closer ps paren @closer ps square parse_ranges(ps)

    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR{Filter}(Any[ranges.args...])
        else
            ranges = EXPR{Filter}(Any[ranges])
        end
        next(ps)
        unshift!(ranges, INSTANCE(ps))
        @catcherror ps cond = @closer ps range @closer ps paren parse_expression(ps)
        unshift!(ranges, cond)
        push!(ret, ranges)
    else
        if ranges isa EXPR{Block}
            append!(ret, ranges)
        else
            push!(ret, ranges)
        end
    end

    # This should reverse order of iterators
    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}(Any[ret])
    end

    return ret
end
