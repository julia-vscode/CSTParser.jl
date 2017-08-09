function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Const}(EXPR[kw, arg], "")
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    kw = INSTANCE(ps)
    @catcherror ps arg = parse_expression(ps)

    ret = EXPR{Global}(EXPR[kw, arg], "")
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    kw = INSTANCE(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    ret = EXPR{Local}(EXPR[kw, arg], "")
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    kw = INSTANCE(ps)
    @catcherror ps args = @default ps closer(ps) ? NOTHING : parse_expression(ps)

    ret = EXPR{Return}(EXPR[kw, args], "")
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, 1 + (0:ps.t.endbyte-ps.t.startbyte), "end")
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(EXPR[], "incorrect use of end")
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSE}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, 1 + (0:ps.t.endbyte-ps.t.startbyte), "else")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], "incorrect use of else")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSEIF}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, 1 + (0:ps.t.endbyte-ps.t.startbyte), "elseif")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], "incorrect use of else")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CATCH}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, 1 + (0:ps.t.endbyte-ps.t.startbyte), "catch")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], "incorrect use of catch")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FINALLY}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :finally)
    ps.errored = true
    return EXPR{ERROR}(EXPR[], "incorrect use of finally")
end
