"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    next(ps)
    start = ps.t.startbyte
    puncs = INSTANCE[INSTANCE(ps)]
    format(ps)
    arg = @closer ps brace @nocloser ps newline parse_expression(ps)
    if arg isa EXPR && arg.head == TUPLE
        append!(puncs, arg.punctuation)
        arg = arg.args
    end
    push!(puncs, INSTANCE(next(ps)))
    format(ps)
    return EXPR(CURLY, [ret, arg...], ret.span + ps.nt.startbyte - start, puncs)
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
