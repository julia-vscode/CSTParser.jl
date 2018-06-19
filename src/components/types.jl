function parse_abstract(ps::ParseState)
    # Switch for v0.6 compatability
    if ps.nt.kind == Tokens.TYPE
        kw1 = KEYWORD(ps)
        kw2 = KEYWORD(next(ps))
        @catcherror ps sig = @default ps @closer ps block parse_expression(ps)
        ret = EXPR{Abstract}(Any[kw1, kw2, sig, KEYWORD(next(ps))])
    else
        kw = KEYWORD(ps)
        @catcherror ps sig = @default ps parse_expression(ps)
        ret = EXPR{Abstract}(Any[kw, sig])
    end
    return ret
end

function parse_primitive(ps::ParseState)
    if ps.nt.kind == Tokens.TYPE
        kw1 = KEYWORD(ps)
        kw2 = KEYWORD(next(ps))
        @catcherror ps sig = @default ps @closer ps ws @closer ps wsop parse_expression(ps)
        @catcherror ps arg = @default ps @closer ps block parse_expression(ps)

        ret = EXPR{Primitive}(Any[kw1, kw2, sig, arg, KEYWORD(next(ps))])
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end

function parse_mutable(ps::ParseState)
    if ps.nt.kind == Tokens.STRUCT
        kw = KEYWORD(ps)
        next(ps)
        @catcherror ps ret = parse_struct(ps, true)
        pushfirst!(ret, kw)
        update_span!(ret)
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end


function parse_struct(ps::ParseState, mutable)
    kw = KEYWORD(ps)
    @catcherror ps sig = @default ps @closer ps block @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    
    return EXPR{mutable ? Mutable : Struct}(Any[kw, sig, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end
