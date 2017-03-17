function parse_do(ps::ParseState, ret)
    next(ps)
    kw = INSTANCE(ps)
    start_col = ps.t.startpos[2]-ret.span
    ret = EXPR(kw, [ret], ret.span - ps.t.startbyte)
    args = EXPR(TUPLE,[], - ps.nt.startbyte)
    @default ps @closer ps comma @closer ps block while !closer(ps)
        a = parse_expression(ps)
        push!(args.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format_comma(ps)
            push!(args.punctuation, INSTANCE(ps))
        end
    end
    args.span += ps.nt.startbyte
    block = @default ps parse_block(ps, start_col)
    push!(ret.args, args)
    push!(ret.args, block)
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    
    return ret
end



function _start_do(x::EXPR)
    return Iterator{:do}(1, 5)
end

function next(x::EXPR, s::Iterator{:do})
    if s.i == 1
       return x.args[1], +s
    elseif s.i == 2 
        return x.head, +s
    elseif s.i == 3 
        return x.args[2], +s
    elseif s.i == 4
        return x.args[3], +s
    else
        return x.punctuation[1], +s
    end
end
