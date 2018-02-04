function parse_for(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps ranges = @default ps parse_ranges(ps)

    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    return EXPR{For}(Any[kw, ranges, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end


function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    arg = @closer ps range @closer ps ws parse_expression(ps)

    if !is_range(arg)
        return make_error(ps, startbyte + (0:length(arg.span)-1),
                          Diagnostics.InvalidIter, "invalid iteration specification")
    end
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(Any[arg])
        while ps.nt.kind == Tokens.COMMA
            push!(arg, PUNCTUATION(next(ps)))

            startbyte = ps.nt.startbyte
            @catcherror ps nextarg = @closer ps comma @closer ps ws parse_expression(ps)
            if !is_range(nextarg)
                return make_error(ps, startbyte + (0:length(arg.span)-1),
                                  Diagnostics.InvalidIter, "invalid iteration specification")
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

    return EXPR{While}(Any[kw, cond, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end




"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, @nospecialize ret)
    kw = KEYWORD(next(ps))
    ret = EXPR{Generator}(Any[ret, kw])
    @catcherror ps ranges = @closer ps paren @closer ps square parse_ranges(ps)

    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR{Filter}(ranges.args)
        else
            ranges = EXPR{Filter}(Any[ranges])
        end
        pushfirst!(ranges, KEYWORD(next(ps)))
        @catcherror ps cond = @closer ps range @closer ps paren parse_expression(ps)
        pushfirst!(ranges, cond)
        push!(ret, ranges)
    else
        if ranges isa EXPR{Block}
            append!(ret, ranges)
        else
            push!(ret, ranges)
        end
    end

    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}(Any[ret])
    end

    return ret
end
