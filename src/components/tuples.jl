"""
    parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple(ps::ParseState, ret::SyntaxNode)
    startbyte = ps.nt.startbyte

    # Parsing
    next(ps)
    op = INSTANCE(ps)
    format_comma(ps)

    if isassignment(ps.nt) && ps.nt.kind != Tokens.APPROX
        if ret isa EXPR{TupleH}
            push!(ret.args, op)
            ret.span += op.span
        else
            ret =  EXPR(TupleH, SyntaxNode[ret, op], ret.span + op.span)
        end
    elseif closer(ps)
        if ret isa EXPR{TupleH} && #(length(ret.punctuation) == 0 || !(first(ret.args) isa PUNCTUATION{Tokens.LPAREN}))
            push!(ret.punctuation, op)
            ret.span += op.span
        else
            ret = EXPR(TupleH, SyntaxNode[ret, op], ret.span + op.span)
        end
    else
        @catcherror ps startbyte nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR{TupleH} && (!(first(ret.args) isa PUNCTUATION{Tokens.LPAREN})) # && length(ret.punctuation) == 0 ||
            push!(ret.args, op)
            push!(ret.args, nextarg) 
            ret.span += ps.nt.startbyte - startbyte
        else
            ret = EXPR(TupleH, SyntaxNode[ret, op, nextarg], ret.span + ps.nt.startbyte - startbyte)
        end
    end
    return ret
end
