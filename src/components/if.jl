parse_kw(ps::ParseState, ::Type{Val{Tokens.IF}}) = parse_if(ps)

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested = false)
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte cond = @default ps @closer ps block @closer ps ws parse_expression(ps)

    ifblock = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps @closer ps ifelse parse_block(ps, ifblock, start_col, Tokens.Kind[Tokens.END, Tokens.ELSE, Tokens.ELSEIF])
    
    if nested
        ret = EXPR{If}(EXPR[cond, ifblock], 0, Variable[], "")
    else
        ret = EXPR{If}(EXPR[kw, cond, ifblock], 0, Variable[], "")
    end

    elseblock = EXPR{Block}(EXPR[], 0, Variable[], "")
    if ps.nt.kind == Tokens.ELSEIF
        next(ps)
        push!(ret.args, INSTANCE(ps))
        startelseblock = ps.nt.startbyte
        
        @catcherror ps startbyte push!(elseblock.args, parse_if(ps, true))
        elseblock.span = ps.nt.startbyte - startelseblock
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind == Tokens.ELSE
        next(ps)
        start_col = ps.t.startpos[2]
        push!(ret.args, INSTANCE(ps))
        @catcherror ps startbyte @default ps parse_block(ps, elseblock, start_col)
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
    if cond isa EXPR{BinarySyntaxOpCall} && cond.args[2] isa EXPR{OP} where OP <: OPERATOR{AssignmentOp}
        push!(ps.diagnostics, Diagnostic{Diagnostics.CondAssignment}(startbyte + kw.span + (0:cond.span), [], ""))
    end
    if cond isa EXPR{LITERAL{Tokens.TRUE}}
        if length(ret.args) == 6
            push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(startbyte + kw.span + cond.span + ret.args[2].span + (0:ret.args[3].span), [], ""))
        end
    elseif cond isa EXPR{LITERAL{Tokens.FALSE}}
        if length(ret.args) == 4
            push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(startbyte + kw.span + cond.span + (0:ret.args[2].span), [], ""))
        end
    end
    ret.span = sum(a.span for a in ret.args)
    return ret
end
