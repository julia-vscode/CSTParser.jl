function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)
    return EXPR(kw, Expression[arg1, arg2], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)
    return EXPR(kw, Expression[arg1, arg2], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[TRUE, arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[FALSE, arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

function next(x::EXPR, s::Iterator{:abstract})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:type})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end
