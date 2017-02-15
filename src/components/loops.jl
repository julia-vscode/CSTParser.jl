function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    start = ps.t.startbyte
    return EXPR(INSTANCE(ps), Expression[], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    start = ps.t.startbyte
    return EXPR(INSTANCE(ps), Expression[], ps.ws.endbyte - start + 1)
end

_start_for(x::Expr) = Iterator{:for}(1, 4)
_start_while(x::Expr) = Iterator{:while}(1, 4)



function next(x::EXPR, s::Iterator{:while})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:for})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:continue})
    if s.i == 1
        return x.head, +s
    end
end

function next(x::EXPR, s::Iterator{:break})
    if s.i == 1
        return x.head, +s
    end
end