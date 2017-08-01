function parse_do(ps::ParseState, ret)
    # Parsing
    next(ps)
    kw = INSTANCE(ps)
    format_kw(ps)

    args = EXPR{TupleH}(EXPR[], Variable[], "")
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)
        push!(args.defs, Variable(Symbol(_arg_id(a).val), get_t(a), args))

        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format_comma(ps)
            push!(args, INSTANCE(ps))
        end
    end
    block = EXPR{Block}(EXPR[], 0, 1:0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, block)

    # Construction
    ret = EXPR{Do}(EXPR[ret, kw], Variable[], "")
    push!(ret, args)
    push!(ret, block)
    next(ps)
    push!(ret, INSTANCE(ps))

    return ret
end
