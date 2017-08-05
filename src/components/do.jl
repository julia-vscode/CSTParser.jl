function parse_do(ps::ParseState, ret)
    # Parsing
    next(ps)
    kw = INSTANCE(ps)

    args = EXPR{TupleH}(EXPR[], "")
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)

        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(args, INSTANCE(ps))
        end
    end
    block = EXPR{Block}(EXPR[], 0, 1:0, "")
    @catcherror ps @default ps parse_block(ps, block)

    # Construction
    ret = EXPR{Do}(EXPR[ret, kw], "")
    push!(ret, args)
    push!(ret, block)
    next(ps)
    push!(ret, INSTANCE(ps))

    return ret
end
