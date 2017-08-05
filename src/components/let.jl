function parse_kw(ps::ParseState, ::Type{Val{Tokens.LET}})
    # Parsing
    ret = EXPR{Let}(EXPR[INSTANCE(ps)], "")

    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)
        push!(ret, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret, INSTANCE(ps))
        end
    end
    block = EXPR{Block}(EXPR[], 0, 1:0, "")
    @catcherror ps @default ps parse_block(ps, block)

    # Construction
    push!(ret, block)
    next(ps)
    push!(ret, INSTANCE(ps))

    return ret
end
