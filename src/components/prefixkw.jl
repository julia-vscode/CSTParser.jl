function parse_const(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Const}(Any[kw, arg])
end

function parse_global(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Global}(Any[kw, arg])
end

function parse_local(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Local}(Any[kw, arg])
end

function parse_return(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps args = closer(ps) ? NOTHING : parse_expression(ps)

    return EXPR{Return}(Any[kw, args])
end

function parse_end(ps::ParseState)
    ret = IDENTIFIER(ps)
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(Any[])
    end
    return ret
end
