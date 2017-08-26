function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Const}(Any[kw, arg])
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    kw = INSTANCE(ps)
    @catcherror ps arg = parse_expression(ps)

    ret = EXPR{Global}(Any[kw, arg])
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Local}(Any[kw, arg])
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    kw = INSTANCE(ps)
    @catcherror ps args = @default ps closer(ps) ? NOTHING : parse_expression(ps)

    ret = EXPR{Return}(Any[kw, args])
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    ret = IDENTIFIER(ps)
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(Any[])
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSE}})
    ret = IDENTIFIER(ps)
    ps.errored = true
    return EXPR{ERROR}(Any[])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSEIF}})
    ret = IDENTIFIER(ps)
    ps.errored = true
    return EXPR{ERROR}(Any[])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CATCH}})
    ret = IDENTIFIER(ps)
    ps.errored = true
    return EXPR{ERROR}(Any[])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FINALLY}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :finally)
    ps.errored = true
    return EXPR{ERROR}(Any[])
end
