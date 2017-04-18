function parse_kw(ps::ParseState, ::Type{Val{Tokens.LET}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    ret = EXPR(INSTANCE(ps), [], -startbyte)
    args = []
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps startbyte a = parse_expression(ps)
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            format_comma(ps)
        end
    end
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    # Construction
    push!(ret.args, block)
    for a in args
        push!(ret.args, a)
    end
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    ret.span += ps.nt.startbyte

    # Linting
    # let span = startbyte + ret.head.span
    #     for (i, a) in enumerate(args)
    #         if !(a isa EXPR && a.head isa OPERATOR{1})
    #             push!(ps.diagnostics, Hint{Hints.LetNonAssignment}(span:a.head))
    #         end
    #         span += a.span + ret.punctuation[i].span
    #     end
    # end
    return ret
end

_start_let(x::EXPR) =  Iterator{:let}(1, 1 + length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:let})
    if s.i == 1
        return x.head, +s
    elseif s.i == s.n
        return x.punctuation[end], +s
    elseif s.i == s.n - 1
        return x.args[1], +s
    elseif iseven(s.i) 
        return x.args[div(s.i, 2) + 1], +s
    elseif isodd(s.i) 
        return x.punctuation[div(s.i - 1, 2)], +s
    end
end
