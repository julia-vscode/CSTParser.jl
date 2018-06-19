function parse_for(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps ranges = @default ps parse_ranges(ps)

    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    return EXPR{For}(Any[kw, ranges, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end


function parse_iter(ps::ParseState)
    startbyte = ps.nt.startbyte
    if ps.nt.kind == Tokens.OUTER && ps.nws.kind != EmptyWS && !Tokens.isoperator(ps.nnt.kind) 
        outer = INSTANCE(next(ps))
        arg = @closer ps range @closer ps ws parse_expression(ps)
        arg.arg1 = EXPR{Outer}([outer, arg.arg1])
        arg.fullspan += outer.fullspan
        arg.span = 1:(outer.fullspan + last(arg.span))
    else
        arg = @closer ps range @closer ps ws parse_expression(ps)
    end
    return arg
end

function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    #TODO: this is slow
    @catcherror ps arg = parse_iter(ps)

    if (arg isa EXPR{Outer} && !is_range(arg.args[2])) || !is_range(arg)
        return make_error(ps, broadcast(+, startbyte, (0:length(arg.span) .- 1)),
                          Diagnostics.InvalidIter, "invalid iteration specification")
    end
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(Any[arg])
        while ps.nt.kind == Tokens.COMMA
            push!(arg, PUNCTUATION(next(ps)))
            @catcherror ps nextarg = parse_iter(ps)
            if (nextarg isa EXPR{Outer} && !is_range(nextarg.args[2])) || !is_range(nextarg)
                return make_error(ps, startbyte .+ (0:length(arg.span) .- 1),
                                  Diagnostics.InvalidIter, "invalid iteration specification")
            end
            push!(arg, nextarg)
        end
    end
    return arg
end


function is_range(x) false end
function is_range(x::BinarySyntaxOpCall) is_eq(x.op) end
function is_range(x::BinaryOpCall) is_in(x.op) || is_elof(x.op) end

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
    elseif ranges isa EXPR{Block}
        append!(ret, ranges)
    else
        push!(ret, ranges)
    end
    

    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}(Any[ret])
    end

    return ret
end
