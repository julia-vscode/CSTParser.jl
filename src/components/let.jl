function parse_kw(ps::ParseState, ::Type{Val{Tokens.LET}})
    start_col = ps.t.startpos[2] + 4

    # Parsing
    ret = EXPR{Let}(EXPR[INSTANCE(ps)], Variable[], "")
    format_kw(ps)

    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)
        push!(ret, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret, INSTANCE(ps))
            format_comma(ps)
        end
    end
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, block, start_col)

    # Construction
    push!(ret, block)
    next(ps)
    push!(ret, INSTANCE(ps))

    return ret
end
