parse_kw(ps::ParseState, ::Type{Val{Tokens.IF}}) = parse_if(ps)

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested = false, puncs = [])
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    cond = @default ps @closer ps ws parse_expression(ps)

    if ps.nt.kind==Tokens.END
        next(ps)
        return EXPR(kw, SyntaxNode[cond, EXPR(BLOCK, SyntaxNode[], 0)], ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)])
    end

    ifblock = EXPR(BLOCK, SyntaxNode[], -ps.nt.startbyte)
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.ELSE && ps.nt.kind!==Tokens.ELSEIF
        push!(ifblock.args, @default ps @closer ps block @closer ps ifelse parse_expression(ps))
    end
    ifblock.span += ps.nt.startbyte

    elseblock = EXPR(BLOCK, SyntaxNode[], 0)
    if ps.nt.kind==Tokens.ELSEIF
        next(ps)
        push!(puncs, INSTANCE(ps))
        startelseblock = ps.nt.startbyte
        push!(elseblock.args, parse_if(ps, true, puncs))
        elseblock.span = ps.nt.startbyte - startelseblock
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind==Tokens.ELSE
        next(ps)
        start_col = ps.t.startpos[2]
        # format(ps)
        push!(puncs, INSTANCE(ps))
        startelseblock = ps.nt.startbyte
        @default ps parse_block(ps, start_col, elseblock)
        elseblock.span = ps.nt.startbyte - startelseblock
    end
    !nested && next(ps)
    !nested && push!(puncs, INSTANCE(ps))
    ret = isempty(elseblock.args) && !elsekw ? 
        EXPR(kw, SyntaxNode[cond, ifblock], ps.nt.startbyte - start, puncs) : 
        EXPR(kw, SyntaxNode[cond, ifblock, elseblock], ps.nt.startbyte - start, puncs)

    # Linting
    if cond isa EXPR && cond.head isa OPERATOR{1}
        push!(ps.hints, Hint{Hints.CondAssignment}(start + kw.span + (0:cond.span)))
    end
    if cond isa LITERAL{Tokens.TRUE}
        if length(ret.args) == 3
            push!(ps.hints, Hint{Hints.DeadCode}(start + kw.span + cond.span + ret.args[2].span + (0:ret.args[3].span)))
        end
    elseif cond isa LITERAL{Tokens.FALSE}
        if length(ret.args) == 2
            push!(ps.hints, Hint{Hints.DeadCode}(start + kw.span + cond.span + (0:ret.args[2].span)))
        end
    end

    return ret
end

function _start_if(x::EXPR)
    if length(x.args) == 2
        return Iterator{:if}(1, 4)
    elseif x.punctuation[end-1] isa KEYWORD{Tokens.ELSE}
        return Iterator{:if}(1, 4 + (length(x.punctuation)-2)*3 + 2)
    else
        return Iterator{:if}(1, 4 + (length(x.punctuation)-1)*3)
    end
end

function next(x::EXPR, s::Iterator{:if})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    else
        haselse = x.punctuation[end-1] isa KEYWORD{Tokens.ELSE}
        nesteds = length(x.punctuation)-1-haselse
        if haselse && s.i == s.n-1
            n = div(s.i-2, 3)-1
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[3], +s
        end
        if mod(s.i-1, 3) == 0
            return x.punctuation[div(s.i-1, 3)], +s
        elseif mod(s.i-2, 3) == 0
            n = div(s.i-2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[1], +s
        else
            n = div(s.i-2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[2], +s
        end
    end
end