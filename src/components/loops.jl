function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte ranges = @default ps parse_ranges(ps)
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)
    next(ps)
    ret = EXPR{For}(EXPR[kw, ranges, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")

    return ret
end


function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    defs = []
    arg = @closer ps range @closer ps comma @closer ps ws parse_expression(ps)
    _track_range_assignment(ps, arg)
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(EXPR[arg], arg.span, Variable[], "")
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(arg.args, INSTANCE(ps))
            format_comma(ps)

            arg.span += last(arg.args).span
            @catcherror ps startbyte nextarg = @closer ps comma @closer ps ws parse_expression(ps)
            _track_range_assignment(ps, nextarg)
            push!(arg.args, nextarg)
            arg.span += last(arg.args).span
        end
    end
    return arg
end

function _track_range_assignment(ps, x) end
function _track_range_assignment(ps, x::EXPR{BinaryOpCall})
    if ((x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}}))
        append!(x.defs, _track_assignment(ps::ParseState, x.args[1], x.args[3]))
    end
end


function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte cond = @default ps @closer ps ws parse_expression(ps)
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)
    next(ps)

    ret = EXPR{While}(EXPR[kw, cond, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    return EXPR{Break}(EXPR[INSTANCE(ps)], ps.nt.startbyte - ps.t.startbyte, Variable[], "")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    return EXPR{Continue}(EXPR[INSTANCE(ps)], ps.nt.startbyte - ps.t.startbyte, Variable[], "")
end


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

    # This should reverse order of iterators
    if ret.args[1] isa EXPR{Generator} || ret.args[1] isa EXPR{Flatten}
        ret = EXPR{Flatten}([ret], ret.span, Variable[], "")
    end

    return ret
end
