parse_kw(ps::ParseState, ::Type{Val{Tokens.IF}}) = parse_if(ps)

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested = false, puncs = [])
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte cond = @default ps @closer ps block @closer ps ws parse_expression(ps)

    @catcherror ps startbyte ifblock = @default ps @closer ps ifelse parse_block(ps, start_col, closers = [Tokens.END, Tokens.ELSE, Tokens.ELSEIF])
    ret = EXPR(If, [kw, cond, ifblock], 0)

    elseblock = EXPR(Block, SyntaxNode[], 0)
    if ps.nt.kind == Tokens.ELSEIF
        next(ps)
        push!(ret.args, INSTANCE(ps))
        startelseblock = ps.nt.startbyte
        
        @catcherror ps startbyte push!(elseblock.args, parse_if(ps, true, puncs))
        elseblock.span = ps.nt.startbyte - startelseblock
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind == Tokens.ELSE
        next(ps)
        start_col = ps.t.startpos[2]
        push!(ret.args, INSTANCE(ps))
        @catcherror ps startbyte @default ps parse_block(ps, start_col, ret = elseblock)
    end

    # Construction
    !nested && next(ps)
    if isempty(elseblock.args) && !elsekw
        ret.span = ps.nt.startbyte - startbyte
    else
        push!(ret.args, elseblock)
        ret.span = ps.nt.startbyte - startbyte
    end
    !nested && push!(ret.args, INSTANCE(ps))

    # Linting
    # if cond isa EXPR && cond.head isa OPERATOR{AssignmentOp}
    #     push!(ps.diagnostics, Diagnostic{Diagnostics.CondAssignment}(startbyte + kw.span + (0:cond.span), []))
    # end
    # if cond isa LITERAL{Tokens.TRUE}
    #     if length(ret.args) == 3
    #         push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(startbyte + kw.span + cond.span + ret.args[2].span + (0:ret.args[3].span), []))
    #     end
    # elseif cond isa LITERAL{Tokens.FALSE}
    #     if length(ret.args) == 2
    #         push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(startbyte + kw.span + cond.span + (0:ret.args[2].span), []))
    #     end
    # end

    return ret
end
