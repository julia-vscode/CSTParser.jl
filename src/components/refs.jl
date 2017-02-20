function parse_ref(ps::ParseState, ret)
    next(ps)
    start = ps.t.startbyte
    puncs = INSTANCE[INSTANCE(ps)]
    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(puncs, INSTANCE(ps))
        ret = EXPR(REF, [ret], ret.span + ps.nt.startbyte - start, puncs)
    else
        args = @nocloser ps newline @closer ps square parse_list(ps, puncs)
        next(ps)
        push!(puncs, INSTANCE(ps))
        ret = EXPR(REF, [ret, args...], ret.span + ps.nt.startbyte - start, puncs)
    end
    return ret
end

_start_ref(x::EXPR) = Iterator{:ref}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:ref})
    if  s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end