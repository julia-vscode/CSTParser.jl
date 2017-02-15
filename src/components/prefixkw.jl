function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    args = Expression[closer(ps) ? NOTHING : parse_expression(ps)]
    return  EXPR(kw, args, ps.ws.endbyte - start + 1)
end

function next(x::EXPR, s::Iterator{:const})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:global})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:local})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:return})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end