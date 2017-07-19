function parse_do(ps::ParseState, ret)
    startbyte = ps.nt.startbyte
    start_col = ps.nt.startpos[2] - ret.span + 4

    # Parsing
    next(ps)
    kw = INSTANCE(ps)
    format_kw(ps)
    
    args = EXPR{TupleH}(EXPR[], - ps.nt.startbyte, Variable[], "")
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps startbyte a = parse_expression(ps)
        push!(args.defs, Variable(Symbol(_arg_id(a).val), get_t(a), args))
        
        push!(args.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format_comma(ps)
            push!(args.args, INSTANCE(ps))
        end
    end
    args.span += ps.nt.startbyte
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)

    # Construction
    ret = EXPR{Do}(EXPR[ret, kw], ret.span - startbyte, Variable[], "")
    push!(ret.args, args)
    push!(ret.args, block)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    
    return ret
end
