function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps ranges = @default ps parse_ranges(ps)
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, block)
    next(ps)
    ret = EXPR{For}(EXPR[kw, ranges, block, INSTANCE(ps)], Variable[], "")

    return ret
end


function parse_ranges(ps::ParseState)
    defs = []
    arg = @closer ps range @closer ps comma @closer ps ws parse_expression(ps)
    _track_range_assignment(ps, arg)
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(EXPR[arg], Variable[], "")
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(arg, INSTANCE(ps))
            format_comma(ps)

            @catcherror ps nextarg = @closer ps comma @closer ps ws parse_expression(ps)
            _track_range_assignment(ps, nextarg)
            push!(arg, nextarg)
        end
    end
    return arg
end

function _track_range_assignment(ps, x) end
function _track_range_assignment(ps, x::EXPR{BinaryOpCall})
    if (x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}})
        append!(x.defs, _track_assignment(ps::ParseState, x.args[1], x.args[3]))
    end
end
function _track_range_assignment(ps, x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
        append!(x.defs, _track_assignment(ps::ParseState, x.args[1], x.args[3]))
    end
end


function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps cond = @default ps @closer ps ws parse_expression(ps)
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, block)
    next(ps)

    ret = EXPR{While}(EXPR[kw, cond, block, INSTANCE(ps)], Variable[], "")

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    return EXPR{Break}(EXPR[INSTANCE(ps)], Variable[], "")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    return EXPR{Continue}(EXPR[INSTANCE(ps)], Variable[], "")
end


"""
parse_generator(ps)

Having hit `for` not at the beginning of an expression return a generator.
Comprehensions are parsed as SQUAREs containing a generator.
"""
function parse_generator(ps::ParseState, ret)
    next(ps)
    kw = INSTANCE(ps)
    ret = EXPR{Generator}(EXPR[ret, kw], Variable[], "")
    @catcherror ps ranges = @closer ps paren @closer ps square parse_ranges(ps)

    if ps.nt.kind == Tokens.IF
        if ranges isa EXPR{Block}
            ranges = EXPR{Filter}(EXPR[ranges.args...], Variable[], "")
        else
            ranges = EXPR{Filter}(EXPR[ranges], Variable[], "")
        end
        next(ps)
        unshift!(ranges, INSTANCE(ps))
        @catcherror ps cond = @closer ps paren parse_expression(ps)
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
        ret = EXPR{Flatten}([ret], Variable[], "")
    end

    return ret
end
