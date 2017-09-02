function parse_const(ps::ParseState)
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Const}(Any[kw, arg])
    return ret
end

function parse_global(ps::ParseState)
    kw = INSTANCE(ps)
    @catcherror ps arg = parse_expression(ps)

    ret = EXPR{Global}(Any[kw, arg])
    return ret
end

function parse_local(ps::ParseState)
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Local}(Any[kw, arg])
    return ret
end

function parse_return(ps::ParseState)
    kw = INSTANCE(ps)
    @catcherror ps args = @default ps closer(ps) ? NOTHING : parse_expression(ps)

    ret = EXPR{Return}(Any[kw, args])
    return ret
end

function parse_end(ps::ParseState)
    ret = IDENTIFIER(ps)
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(Any[])
    end
    return ret
end
