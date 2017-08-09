"""
    parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple(ps::ParseState, ret)
    next(ps)
    op = INSTANCE(ps)

    if isassignment(ps.nt) && ps.nt.kind != Tokens.APPROX
        if ret isa EXPR{TupleH}
            push!(ret, op)
        else
            ret =  EXPR{TupleH}(EXPR[ret, op], "")
        end
    elseif closer(ps)
        if ret isa EXPR{TupleH}
            push!(ret, op)
        else
            ret = EXPR{TupleH}(EXPR[ret, op], "")
        end
    else
        @catcherror ps nextarg = @closer ps tuple parse_expression(ps)
        if ret isa EXPR{TupleH} && (!(first(ret.args) isa EXPR{PUNCTUATION{Tokens.LPAREN}}))
            push!(ret, op)
            push!(ret, nextarg)
        else
            ret = EXPR{TupleH}(EXPR[ret, op, nextarg], "")
        end
    end
    return ret
end
