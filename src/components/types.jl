function parse_abstract(ps::ParseState)
    # Switch for v0.6 compatability
    if ps.nt.kind == Tokens.TYPE
        kw1 = INSTANCE(ps)
        next(ps)
        kw2 = INSTANCE(ps)

        @catcherror ps sig = @default ps @closer ps block parse_expression(ps)

        next(ps)
        ret = EXPR{Abstract}(Any[kw1, kw2, sig, INSTANCE(ps)])
    else
        kw = INSTANCE(ps)
        @catcherror ps sig = @default ps parse_expression(ps)

        ret = EXPR{Abstract}(Any[kw, sig])
    end
    return ret
end

function parse_bitstype(ps::ParseState)
    kw = INSTANCE(ps)

    @catcherror ps arg1 = @default ps @closer ps ws @closer ps wsop parse_expression(ps)
    @catcherror ps arg2 = @default ps parse_expression(ps)

    ret = EXPR{Bitstype}(Any[kw, arg1, arg2])
    return ret
end

function parse_primitive(ps::ParseState)
    if ps.nt.kind == Tokens.TYPE
        kw1 = INSTANCE(ps)
        next(ps)
        kw2 = INSTANCE(ps)
        @catcherror ps sig = @default ps @closer ps ws @closer ps wsop parse_expression(ps)
        @catcherror ps arg = @default ps @closer ps block parse_expression(ps)

        next(ps)
        ret = EXPR{Primitive}(Any[kw1, kw2, sig, arg, INSTANCE(ps)])
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end

function parse_typealias(ps::ParseState)
    kw = INSTANCE(ps)

    @catcherror ps arg1 = @closer ps ws @closer ps wsop parse_expression(ps)
    @catcherror ps arg2 = parse_expression(ps)

    return EXPR{TypeAlias}(Any[kw, arg1, arg2])
end

function parse_mutable(ps::ParseState)
    if ps.nt.kind == Tokens.STRUCT
        kw = INSTANCE(ps)
        next(ps)
        @catcherror ps ret = parse_struct(ps, TRUE)
        unshift!(ret, kw)
        update_span!(ret)
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end


function parse_struct(ps::ParseState, mutable)
    kw = INSTANCE(ps)
    @catcherror ps sig = @default ps @closer ps block @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    # Construction
    T = mutable == TRUE ? Tokens.TYPE : Tokens.IMMUTABLE
    
    ret = EXPR{mutable == TRUE ? Mutable : Struct}(Any[kw, sig, EXPR{Block}(blockargs), INSTANCE(next(ps))])
    return ret
end
