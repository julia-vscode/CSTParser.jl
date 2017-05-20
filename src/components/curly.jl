"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma 
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    startbyte = ps.nt.startbyte - ret.span
    next(ps)
    format_lbracket(ps)
    ret = EXPR{Curly}(EXPR[ret, INSTANCE(ps)], ret.span - ps.t.startbyte, Variable[], "")

    @catcherror ps startbyte @default ps @nocloser ps inwhere @closer ps brace parse_comma_sep(ps, ret, true, false, false)
    next(ps)
    format_rbracket(ps)
    push!(ret.args, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    return ret
end

function parse_cell1d(ps::ParseState)
    startbyte = ps.t.startbyte
    format_lbracket(ps)
    ret = EXPR{Cell1d}(EXPR[INSTANCE(ps)], -startbyte, Variable[], "")
    @catcherror ps startbyte @default ps @closer ps brace parse_comma_sep(ps, ret, true, false, false)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    format_rbracket(ps)
    ret.span += ps.nt.startbyte
    return ret
end
