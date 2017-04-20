"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    startbyte = ps.nt.startbyte - ret.span
    next(ps)
    format_lbracket(ps)
    ret = EXPR(CURLY, [ret], ret.span - ps.t.startbyte, [INSTANCE(ps)])

    @catcherror ps startbyte @default ps @closer ps brace parse_comma_sep(ps, ret)
    next(ps)
    format_rbracket(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    return ret
end

function parse_cell1d(ps::ParseState)
    startbyte = ps.t.startbyte
    format_lbracket(ps)
    ret = EXPR(CELL1D, [], -startbyte, [INSTANCE(ps)])
    @catcherror ps startbyte @default ps @closer ps brace parse_comma_sep(ps, ret)
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    format_rbracket(ps)
    ret.span += ps.nt.startbyte
    return ret
end

_start_curly(x::EXPR) = Iterator{:curly}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:curly})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return x.punctuation[1], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i + 1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end
