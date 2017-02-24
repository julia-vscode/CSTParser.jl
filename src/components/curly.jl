"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    next(ps)
    format(ps)
    ret = EXPR(CURLY, [ret], ret.span - ps.t.startbyte, [INSTANCE(ps)])

    @nocloser ps newline @closer ps comma @closer ps brace while !closer(ps)
        push!(ret.args, parse_expression(ps))
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format(ps)
            push!(ret.punctuation, INSTANCE(ps))
        end
    end
    next(ps)
    format(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    return ret
end

_start_curly(x::EXPR) = Iterator{:curly}(1, length(x.args)*2)

function next(x::EXPR, s::Iterator{:curly})
    if s.i==1
        return x.args[1], +s
    elseif s.i==2
        return x.punctuation[1], +s
    elseif s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end
