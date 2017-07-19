function parse_kw(ps::ParseState, ::Type{Val{Tokens.LET}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    ret = EXPR{Let}(EXPR[INSTANCE(ps)], -startbyte, Variable[], "")
    format_kw(ps)

    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps startbyte a = parse_expression(ps)
        push!(ret.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_comma(ps)
        end
    end
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)

    # Construction
    push!(ret.args, block)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    ret.span += ps.nt.startbyte

    return ret
end
