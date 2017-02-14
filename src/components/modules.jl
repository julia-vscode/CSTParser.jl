function parse_imports(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    M = INSTANCE[]
    if ps.nt.kind==Tokens.DDOT
        push!(M, INSTANCE{OPERATOR{15},Tokens.DOT}(1, ps.nt.startbyte))
        push!(M, INSTANCE{OPERATOR{15},Tokens.DOT}(1, ps.nt.startbyte + 1))
        next(ps)
    end
    @assert ps.nt.kind == Tokens.IDENTIFIER "incomplete import statement"
    push!(M, INSTANCE(next(ps)))
    puncs = INSTANCE[]
    while ps.nt.kind==Tokens.DOT
        push!(puncs, INSTANCE(next(ps)))
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(M, INSTANCE(next(ps)))
    end
    if closer(ps)
        ret =  EXPR(kw, M, ps.ws.endbyte - start + 1, puncs)
    else
        @assert ps.nt.kind == Tokens.COLON
        push!(puncs, INSTANCE(next(ps)))
        args = Vector{INSTANCE}[]
        while ps.nt.kind == Tokens.IDENTIFIER && !closer(ps)
            a = INSTANCE[INSTANCE(next(ps))]
            while ps.nt.kind == Tokens.DOT
                push!(puncs, INSTANCE(next(ps)))
                push!(a, INSTANCE(next(ps)))
            end
            if ps.nt.kind == Tokens.COMMA
                push!(args, a)
                !closer(ps) && push!(puncs, INSTANCE(next(ps)))
            else
                push!(args, a)
                break
            end
        end
        if length(args)==1
            push!(M, first(args)...)
            ret = EXPR(kw, M, ps.ws.endbyte - start + 1, puncs)
        else
            ret = EXPR(INSTANCE{HEAD,Tokens.TOPLEVEL}(kw.span, start), Expression[], ps.ws.endbyte - start + 1, puncs)
            for a in args
                push!(ret.args, EXPR(kw, vcat(M, a), sum(y.span for y in a) + length(a) - 1))
            end
        end
    end
    return ret
end

function parse_export(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    @assert ps.nt.kind == Tokens.IDENTIFIER "incomplete export statement"
    args = INSTANCE[INSTANCE(next(ps))]
    puncs = INSTANCE[]
    while ps.nt.kind==Tokens.COMMA
        push!(puncs, INSTANCE(next(ps)))
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(args, INSTANCE(next(ps)))
    end

    return EXPR(kw, args, ps.ws.endbyte - start + 1, puncs)
end

function _start_imports(x::EXPR)
    return Iterator{:imports}(1, 1 + length(x.args) + length(x.punctuation)) 
end

function next(x::EXPR, s::Iterator{:imports})
    if s.i == 1
        return x.head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:export})
    if s.i == 1
        return x.head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end
