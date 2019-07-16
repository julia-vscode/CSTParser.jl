"""
parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple end

@static if VERSION > v"1.1-"
    function parse_tuple(ps::ParseState, @nospecialize(ret))
        op = mPUNCTUATION(next(ps))
        if typof(ret) == TupleH
            if (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                push!(ret, op)
            elseif closer(ps)
                ps.errored = true
                push!(ret, mErrorToken(op, Unknown))
            else
                nextarg = @closer ps tuple parse_expression(ps)
                if !(is_lparen(first(ret.args)))
                    push!(ret, op)
                    push!(ret, nextarg)
                else
                    ret = EXPR(TupleH, EXPR[ret, op, nextarg])
                end
            end
        else
            if (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                ret = EXPR(TupleH, EXPR[ret, op])
            elseif closer(ps)
                ps.errored = true
                ret = mErrorToken(EXPR(TupleH, EXPR[ret, op]), Unknown)
            else
                nextarg = @closer ps tuple parse_expression(ps)
                ret = EXPR(TupleH, EXPR[ret, op, nextarg])
            end
        end
        return ret
    end
else
    function parse_tuple(ps::ParseState, @nospecialize(ret))
        op = mPUNCTUATION(next(ps))
        if typof(ret) === TupleH
            if closer(ps) || (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                push!(ret, op)
            else
                nextarg = @closer ps tuple parse_expression(ps)
                if !(is_lparen(first(ret.args)))
                    push!(ret, op)
                    push!(ret, nextarg)
                else
                    ret = EXPR(TupleH, EXPR[ret, op, nextarg])
                end
            end
        else
            if closer(ps) || (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                ret = EXPR(TupleH, EXPR[ret, op])
            else
                nextarg = @closer ps tuple parse_expression(ps)
                ret = EXPR(TupleH, EXPR[ret, op, nextarg])
            end
        end
        return ret
    end
    
end

"""
    parse_array(ps)
Having hit '[' return either:
+ A vect
+ A vcat
+ A comprehension
+ An array (vcat of hcats)
"""
function parse_array(ps::ParseState, isref = false)
    args = EXPR[mPUNCTUATION(ps)]

    if kindof(ps.nt) == Tokens.RSQUARE
        accept_rsquare(ps, args)
        ret = EXPR(Vect, args)
    else
        first_arg = @nocloser ps newline @closesquare ps  @closer ps insquare @closer ps ws @closer ps wsop @closer ps comma parse_expression(ps)
        if isref && _do_kw_convert(ps, first_arg)
            first_arg = _kw_convert(first_arg)
        end

        if kindof(ps.nt) == Tokens.RSQUARE
            if typof(first_arg) === Generator || typof(first_arg) === Flatten
                accept_rsquare(ps, args)

                if typof(first_arg.args[1]) === BinaryOpCall && is_pairarrow(first_arg.args[1].args[2])
                    return EXPR(DictComprehension, EXPR[args[1], first_arg, INSTANCE(ps)])
                else
                    return EXPR(Comprehension, EXPR[args[1], first_arg, INSTANCE(ps)])
                end
            elseif kindof(ps.ws) == SemiColonWS
                push!(args, first_arg)
                accept_rsquare(ps, args)
                return EXPR(Vcat, args)
            else
                push!(args, first_arg)
                accept_rsquare(ps, args)
                ret = EXPR(Vect, args)
            end
        elseif kindof(ps.nt) == Tokens.COMMA
            etype = Vect
            push!(args, first_arg)
            accept_comma(ps, args)
            @closesquare ps parse_comma_sep(ps, args, isref)
            accept_rsquare(ps, args)
            return EXPR(etype, args)
        elseif kindof(ps.ws) == NewLineWS
            ret = EXPR(Vcat, args)
            push!(ret, first_arg)
            while kindof(ps.nt) != Tokens.RSQUARE
                if kindof(ps.nt) == Tokens.ENDMARKER
                    break
                end
                a = @closesquare ps  parse_expression(ps)
                push!(ret, a)
            end
            accept_rsquare(ps, ret)
            update_span!(ret)
            return ret
        elseif kindof(ps.ws) == WS || kindof(ps.ws) == SemiColonWS
            first_row = EXPR(Hcat, EXPR[first_arg])
            while kindof(ps.nt) != Tokens.RSQUARE && kindof(ps.ws) != NewLineWS && kindof(ps.ws) != SemiColonWS
                if kindof(ps.nt) == Tokens.ENDMARKER
                    break
                end
                a = @closesquare ps @closer ps ws @closer ps wsop parse_expression(ps)
                push!(first_row, a)
            end
            if kindof(ps.nt) == Tokens.RSQUARE && kindof(ps.ws) != SemiColonWS
                if length(first_row.args) == 1
                    first_row = EXPR(Vcat, first_row.args)
                end
                push!(first_row, INSTANCE(next(ps)))
                pushfirst!(first_row, args[1])
                update_span!(first_row)
                return first_row
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row = EXPR(Row, first_row.args)
                end
                ret = EXPR(Vcat, EXPR[args[1], first_row])
                while kindof(ps.nt) != Tokens.RSQUARE
                    if kindof(ps.nt) == Tokens.ENDMARKER
                        break
                    end
                    first_arg = @closesquare ps @closer ps ws @closer ps wsop parse_expression(ps)
                    push!(ret, EXPR(Row, EXPR[first_arg]))
                    while kindof(ps.nt) != Tokens.RSQUARE && kindof(ps.ws) != NewLineWS && kindof(ps.ws) != SemiColonWS
                        if kindof(ps.nt) == Tokens.ENDMARKER
                            break
                        end
                        a = @closesquare ps @closer ps ws @closer ps wsop parse_expression(ps)
                        push!(last(ret.args), a)
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = setparent!(ret.args[end].args[1], ret)
                    end
                    update_span!(ret)
                end
                accept_rsquare(ps, ret)
                update_span!(ret)
                return ret
            end
        else
            ret = EXPR(Vect, args)
            push!(ret, first_arg)
            push!(ret, accept_rsquare(ps))
        end
    end
    return ret
end

"""
    parse_ref(ps, ret)

Handles cases where an expression - `ret` - is followed by
`[`. Parses the following bracketed expression and modifies it's
`.head` appropriately.
"""
function parse_ref(ps::ParseState, @nospecialize(ret))
    next(ps)
    ref = parse_array(ps, true)
    if typof(ref) === Vect
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(Ref, args)
    elseif typof(ref) === Hcat
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(TypedHcat, args)
    elseif typof(ref) === Vcat
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(TypedVcat, args)
    else
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(TypedComprehension, args)
    end
end




"""
parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    args = EXPR[ret, mPUNCTUATION(next(ps))]
    parse_comma_sep(ps, args, true)
    accept_rbrace(ps, args)
    return EXPR(Curly, args)
end

function parse_braces(ps::ParseState)
    # args = EXPR[mPUNCTUATION(ps)]
    # parse_comma_sep(ps, args, true)
    # accept_rbrace(ps, args)
    # return EXPR(Braces, args)
    return @default ps @nocloser ps inwhere parse_barray(ps)
end


function parse_barray(ps::ParseState)
    args = EXPR[mPUNCTUATION(ps)]

    if kindof(ps.nt) == Tokens.RBRACE
        accept_rbrace(ps, args)
        ret = EXPR(Braces, args)
    else
        first_arg = @nocloser ps newline @closebrace ps  @closer ps ws @closer ps wsop @closer ps comma parse_expression(ps)
        if kindof(ps.nt) == Tokens.RBRACE
            push!(args, first_arg)
            if kindof(ps.ws) == SemiColonWS
                push!(args, EXPR(Parameters, EXPR[]))
            end
            accept_rbrace(ps, args)
            ret = EXPR(Braces, args)
        elseif kindof(ps.nt) == Tokens.COMMA
            push!(args, first_arg)
            accept_comma(ps, args)
            @closebrace ps parse_comma_sep(ps, args, true)
            accept_rbrace(ps, args)
            return EXPR(Braces, args)
        elseif kindof(ps.ws) == NewLineWS
            ret = EXPR(BracesCat, args)
            push!(ret, first_arg)
            while kindof(ps.nt) != Tokens.RBRACE
                if kindof(ps.nt) == Tokens.ENDMARKER
                    break
                end
                a = @closebrace ps  parse_expression(ps)
                push!(ret, a)
            end
            accept_rsquare(ps, ret)
            update_span!(ret)
            return ret
        elseif kindof(ps.ws) == WS || kindof(ps.ws) == SemiColonWS
            first_row = EXPR(Row, EXPR[first_arg])
            while kindof(ps.nt) != Tokens.RBRACE && kindof(ps.ws) != NewLineWS && kindof(ps.ws) != SemiColonWS
                if kindof(ps.nt) == Tokens.ENDMARKER
                    break
                end
                a = @closebrace ps @closer ps ws @closer ps wsop parse_expression(ps)
                push!(first_row, a)
            end
            if kindof(ps.nt) == Tokens.RBRACE && kindof(ps.ws) != SemiColonWS
                if length(first_row.args) == 1
                    first_row = EXPR(BracesCat, first_row.args)
                end
                push!(args, first_row)
                push!(args, INSTANCE(next(ps)))
                return EXPR(BracesCat, args)
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row = EXPR(Row, first_row.args)
                end
                ret = EXPR(BracesCat, EXPR[args[1], first_row])
                while kindof(ps.nt) != Tokens.RBRACE
                    if kindof(ps.nt) == Tokens.ENDMARKER
                        break
                    end
                    first_arg = @closebrace ps @closer ps ws @closer ps wsop parse_expression(ps)
                    push!(ret, EXPR(Row, EXPR[first_arg]))
                    while kindof(ps.nt) != Tokens.RBRACE && kindof(ps.ws) != NewLineWS && kindof(ps.ws) != SemiColonWS
                        if kindof(ps.nt) == Tokens.ENDMARKER
                            break
                        end
                        a = @closebrace ps @closer ps ws @closer ps wsop parse_expression(ps)
                        push!(last(ret.args), a)
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = setparent!(ret.args[end].args[1], ret)
                    end
                    update_span!(ret)
                end
                accept_rbrace(ps, ret)
                update_span!(ret)
                return ret
            end
        else
            ret = EXPR(Braces, args)
            push!(ret, first_arg)
            push!(ret, accept_rbrace(ps))
        end
    end
    return ret
end