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
        push!(args.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format_comma(ps)
            push!(args.args, INSTANCE(ps))
        end
    end
    args.span += ps.nt.startbyte
    # _lint_do(ps, args, ps.nt.startbyte - args.span)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    # Construction
    ret = EXPR{Do}(EXPR[ret, kw], ret.span - startbyte, Variable[], "")
    push!(ret.args, args)
    push!(ret.args, block)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    ret.span += ps.nt.startbyte
    
    return ret
end


function _lint_do(ps::ParseState, sig, loc)
    args = []
    for (i, arg) in enumerate(sig.args)
        _lint_arg(ps, arg, args, i, NOTHING, length(sig.args), length(sig.args) + 1, loc)
    end
    sig.defs = (a -> Variable(a[1], a[2], sig)).(args)
end
