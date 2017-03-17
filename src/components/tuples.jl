"""
    parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple(ps::ParseState, ret)
    next(ps)
    op = INSTANCE(ps)
    format_comma(ps)

    start = ps.t.startbyte
    if isassignment(ps.nt)
        if ret isa EXPR && ret.head!=TUPLE
            ret =  EXPR(TUPLE, SyntaxNode[ret], ps.nt.startbyte - start, INSTANCE[op])
        end
    elseif closer(ps)
        if ret isa EXPR && ret.head==TUPLE && (length(ret.punctuation)==0 || !(first(ret.punctuation) isa PUNCTUATION{Tokens.LPAREN}))
            push!(ret.punctuation, op)
            ret.span += op.span
        else
            ret = EXPR(TUPLE, SyntaxNode[ret], ret.span + op.span, INSTANCE[op])
        end
    else
        nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR && ret.head==TUPLE && (length(ret.punctuation)==0 || !(first(ret.punctuation) isa PUNCTUATION{Tokens.LPAREN}))
            push!(ret.args, nextarg) 
            push!(ret.punctuation, op)
            ret.span += ps.nt.startbyte - start
        else
            ret =  EXPR(TUPLE, SyntaxNode[ret, nextarg], ret.span+ps.nt.startbyte - start, INSTANCE[op])
        end
    end
    return ret
end

function next(x::EXPR, s::Iterator{:tuple})
    if isodd(s.i)
        return x.punctuation[div(s.i+1, 2)], +s
    elseif s.i==s.n
        return last(x.punctuation), +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:tuplenoparen})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end