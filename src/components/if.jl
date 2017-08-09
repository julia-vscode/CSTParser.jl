parse_kw(ps::ParseState, ::Type{Val{Tokens.IF}}) = parse_if(ps)

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested = false)
    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps cond = @default ps @closer ps block @closer ps ws parse_expression(ps)

    ifblock = EXPR{Block}(EXPR[], 0, 1:0, "")
    @catcherror ps @default ps @closer ps ifelse parse_block(ps, ifblock, Tokens.Kind[Tokens.END, Tokens.ELSE, Tokens.ELSEIF])

    if nested
        ret = EXPR{If}(EXPR[cond, ifblock], "")
    else
        ret = EXPR{If}(EXPR[kw, cond, ifblock], "")
    end

    elseblock = EXPR{Block}(EXPR[], 0, 1:0, "")
    if ps.nt.kind == Tokens.ELSEIF
        next(ps)
        push!(ret, INSTANCE(ps))

        @catcherror ps push!(elseblock, parse_if(ps, true))
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind == Tokens.ELSE
        next(ps)
        push!(ret, INSTANCE(ps))
        @catcherror ps @default ps parse_block(ps, elseblock)
    end

    # Construction
    !nested && next(ps)
    if !(isempty(elseblock.args) && !elsekw)
        push!(ret, elseblock)
    end
    !nested && push!(ret, INSTANCE(ps))

    return ret
end
