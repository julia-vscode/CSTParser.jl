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
    @catcherror ps startbyte cond = @default ps @closer ps ws parse_expression(ps)

    @catcherror ps startbyte ifblock = @default ps @closer ps ifelse parse_block(ps, start_col, closers = [Tokens.END, Tokens.ELSE, Tokens.ELSEIF])

    elseblock = EXPR(BLOCK, SyntaxNode[], 0)
    if ps.nt.kind == Tokens.ELSEIF
        next(ps)
        push!(puncs, INSTANCE(ps))
        startelseblock = ps.nt.startbyte
        
        @catcherror ps startbyte push!(elseblock.args, parse_if(ps, true, puncs))
        elseblock.span = ps.nt.startbyte - startelseblock
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind == Tokens.ELSE
        next(ps)
        start_col = ps.t.startpos[2]
        push!(puncs, INSTANCE(ps))
        @catcherror ps startbyte @default ps parse_block(ps, start_col, ret = elseblock)
    end

    # Construction
    !nested && next(ps)
    !nested && push!(puncs, INSTANCE(ps))
    ret = isempty(elseblock.args) && !elsekw ? 
        EXPR(kw, SyntaxNode[cond, ifblock], ps.nt.startbyte - startbyte, puncs) : 
        EXPR(kw, SyntaxNode[cond, ifblock, elseblock], ps.nt.startbyte - startbyte, puncs)

    # Linting
    if cond isa EXPR && cond.head isa OPERATOR{1}
        push!(ps.diagnostics, Hint{Hints.CondAssignment}(startbyte + kw.span + (0:cond.span)))
    end
    if cond isa LITERAL{Tokens.TRUE}
        if length(ret.args) == 3
            push!(ps.diagnostics, Hint{Hints.DeadCode}(startbyte + kw.span + cond.span + ret.args[2].span + (0:ret.args[3].span)))
        end
    elseif cond isa LITERAL{Tokens.FALSE}
        if length(ret.args) == 2
            push!(ps.diagnostics, Hint{Hints.DeadCode}(startbyte + kw.span + cond.span + (0:ret.args[2].span)))
        end
    end

    return ret
end

function _start_if(x::EXPR)
    if length(x.args) == 2
        return Iterator{:if}(1, 4)
    elseif x.punctuation[end - 1] isa KEYWORD{Tokens.ELSE}
        return Iterator{:if}(1, 4 + (length(x.punctuation) - 2) * 3 + 2)
    else
        return Iterator{:if}(1, 4 + (length(x.punctuation) - 1) * 3)
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
        haselse = x.punctuation[end - 1] isa KEYWORD{Tokens.ELSE}
        nesteds = length(x.punctuation) - 1 - haselse
        if haselse && s.i == s.n - 1
            n = div(s.i - 2, 3) - 1
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[3], +s
        end
        if mod(s.i - 1, 3) == 0
            return x.punctuation[div(s.i - 1, 3)], +s
        elseif mod(s.i - 2, 3) == 0
            n = div(s.i - 2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[1], +s
        else
            n = div(s.i - 2, 3)
            y = x
            for i = 1:n
                y = y.args[3].args[1]
            end
            return y.args[2], +s
        end
    end
end