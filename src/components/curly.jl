"""
    parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    next(ps)
    format_lbracket(ps)
    ret = EXPR{Curly}(EXPR[ret, INSTANCE(ps)], Variable[], "")

    @catcherror ps  @default ps @nocloser ps inwhere @closer ps brace parse_comma_sep(ps, ret, true, false, false)
    next(ps)
    format_rbracket(ps)
    push!(ret, INSTANCE(ps))
    return ret
end

function parse_cell1d(ps::ParseState)
    format_lbracket(ps)
    ret = EXPR{Cell1d}(EXPR[INSTANCE(ps)], Variable[], "")
    @catcherror ps @default ps @closer ps brace parse_comma_sep(ps, ret, true, false, false)
    next(ps)
    push!(ret, INSTANCE(ps))
    format_rbracket(ps)
    return ret
end
