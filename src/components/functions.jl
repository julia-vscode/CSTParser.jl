function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end


_start_function(x::EXPR) = Iterator{:function}(1, 4)

function next(x::EXPR, s::Iterator{:function})
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