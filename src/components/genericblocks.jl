function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.DO}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end
function parse_kw(ps::ParseState, ::Type{Val{Tokens.LET}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end


