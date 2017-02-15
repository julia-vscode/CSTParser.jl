function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    start = ps.t.startbyte
    ret = EXPR(MACROCALL, [INSTANCE(next(ps))], -start, [AT_SIGN])
    if isempty(ps.ws) && ps.nt.kind == Tokens.LPAREN
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
        args = @nocloser ps newline @closer ps paren parse_list(ps, ret.punctuation)
        append!(ret.args, args)
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
    else
        while !closer(ps)
            a = @closer ps ws parse_expression(ps)
            push!(ret.args, a)
        end
        ret.span += ps.t.endbyte + 1
    end
    return ret
end

function _start_macrocall(x::EXPR)
    return Iterator{:macrocall}(1, length(x.args) + 1)
end

function next(x::EXPR, s::Iterator{:macrocall})
    if s.i == 1
        return x.punctuation[1], +s
    else
        return x.args[s.i-1], +s
    end
end
