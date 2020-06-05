"""
parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple end

@static if VERSION > v"1.1-"
    function parse_tuple(ps::ParseState, ret::EXPR)
        op = EXPR(next(ps))
        if istuple(ret)
            if (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                pushtotrivia!(ret, op)
            elseif closer(ps)
                pushtotrivia!(ret, mErrorToken(ps, op, Unknown))
            else
                nextarg = @closer ps :tuple parse_expression(ps)
                if !(is_lparen(first(ret.trivia)))
                    pushtotrivia!(ret, op)
                    push!(ret, nextarg)
                else
                    ret = EXPR(:Tuple, EXPR[ret, nextarg], EXPR[op])
                end
            end
        else
            if (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                ret = EXPR(:Tuple, EXPR[ret, op])
            elseif closer(ps)
                ret = mErrorToken(ps, EXPR(:Tuple, EXPR[ret], EXPR[op]), Unknown)
            else
                nextarg = @closer ps :tuple parse_expression(ps)
                ret = EXPR(:Tuple, EXPR[ret, nextarg], EXPR[op])
            end
        end
        return ret
    end
else
    function parse_tuple(ps::ParseState, ret::EXPR)
        op = EXPR(next(ps))
        if istuple(ret)
            if closer(ps) || (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                push!(ret, op)
            else
                nextarg = @closer ps :tuple parse_expression(ps)
                if !(is_lparen(first(ret.args)))
                    push!(ret, op)
                    push!(ret, nextarg)
                else
                    ret = EXPR(:Tuple, EXPR[ret, op, nextarg])
                end
            end
        else
            if closer(ps) || (isassignment(ps.nt) && kindof(ps.nt) != Tokens.APPROX)
                ret = EXPR(:Tuple, EXPR[ret, op])
            else
                nextarg = @closer ps :tuple parse_expression(ps)
                ret = EXPR(:Tuple, EXPR[ret, op, nextarg])
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
    args = EXPR[]
    trivia = EXPR[EXPR(ps)]
    if kindof(ps.nt) === Tokens.RSQUARE
        push!(trivia, accept_rsquare(ps))
        ret = EXPR(:Vect, args, trivia)
    else
        first_arg = @nocloser ps :newline @closesquare ps  @closer ps :insquare @closer ps :ws @closer ps :wsop @closer ps :comma parse_expression(ps)
        if isref && _do_kw_convert(ps, first_arg)
            first_arg = _kw_convert(first_arg)
        end

        if kindof(ps.nt) === Tokens.RSQUARE
            if headof(first_arg) === :Generator || headof(first_arg) === :Flatten
                push!(trivia, accept_rsquare(ps))
                if isbinarycall(first_arg.args[1]) && is_pairarrow(first_arg.args[1].args[2])
                    return EXPR(:Dict_Comprehension, EXPR[first_arg], trivia)
                else
                    return EXPR(:Comprehension, EXPR[first_arg], trivia)
                end
            elseif kindof(ps.ws) == SemiColonWS
                push!(args, first_arg)
                push!(trivia, accept_rsquare(ps))
                return EXPR(:Vcat, args, trivia)
            else
                push!(args, first_arg)
                push!(trivia, accept_rsquare(ps))
                ret = EXPR(:Vect, args, trivia)
            end
        elseif iscomma(ps.nt)
            etype = :Vect
            push!(args, first_arg)
            push!(trivia, accept_comma(ps))
            @closesquare ps parse_comma_sep(ps, args, trivia, isref, insertfirst = true)
            push!(trivia, accept_rsquare(ps))
            return EXPR(etype, args, trivia)
        elseif kindof(ps.ws) == WS || kindof(ps.ws) == SemiColonWS || kindof(ps.ws) == NewLineWS
            ps.closer.inref = false
            args1 = EXPR[first_arg]

            while kindof(ps.nt) !== Tokens.RSQUARE && kindof(ps.ws) !== NewLineWS && kindof(ps.ws) !== SemiColonWS && kindof(ps.nt) !== Tokens.ENDMARKER
                a = @closesquare ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                push!(args1, a)
            end
            if kindof(ps.nt) === Tokens.RSQUARE && kindof(ps.ws) != SemiColonWS
                push!(trivia, accept_rsquare(ps))
                if length(args1) == 1
                    return EXPR(:Vcat, args1, trivia)
                else
                    return EXPR(:Hcat, args1, trivia)
                end
            else
                if length(args1) == 1
                    first_row = args1[1]
                else
                    first_row = EXPR(:Row, args1, nothing)
                end
                push!(args, first_row)
                while kindof(ps.nt) !== Tokens.RSQUARE && kindof(ps.nt) !== Tokens.ENDMARKER
                    first_arg = @closesquare ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                    args2 = EXPR[first_arg]
                    while kindof(ps.nt) !== Tokens.RSQUARE && kindof(ps.ws) !== NewLineWS && kindof(ps.ws) !== SemiColonWS && kindof(ps.nt) !== Tokens.ENDMARKER
                        a = @closesquare ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                        
                        push!(args2, a)
                    end
                    # if only one entry dont use :row
                    if length(args2) == 1
                        push!(args, args2[1])
                    else
                        push!(args, EXPR(:Row, args2, nothing))
                    end
                end
                push!(trivia, accept_rsquare(ps))
                return EXPR(:Vcat, args, trivia)
            end
        else
            push!(args, first_arg)
            push!(trivia, accept_rsquare(ps))
            ret = EXPR(:Vect, args, trivia)
        end
    end
    return ret
end

function parse_array_row()
    
end

"""
    parse_ref(ps, ret)

Handles cases where an expression - `ret` - is followed by
`[`. Parses the following bracketed expression and modifies it's
`.head` appropriately.
"""
function parse_ref(ps::ParseState, ret::EXPR)
    next(ps)
    ref = @closer ps :inref @nocloser ps :inwhere parse_array(ps, true)
    if headof(ref) === :Vect
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(:Ref, args, ref.trivia)
    elseif headof(ref) === :Hcat
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(:Typed_Hcat, args, ref.trivia)
    elseif headof(ref) === :Vcat
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(:Typed_Vcat, args, ref.trivia)
    else
        args = EXPR[ret]
        for a in ref.args
            push!(args, a)
        end
        return EXPR(:Typed_Comprehension, args, ref.trivia)
    end
end




"""
parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma
seperated list.
"""
function parse_curly(ps::ParseState, ret::EXPR)
    args = EXPR[ret]
    trivia = EXPR[EXPR(next(ps))]
    parse_comma_sep(ps, args, trivia, true)
    accept_rbrace(ps, trivia)
    return EXPR(:Curly, args, trivia)
end

function parse_braces(ps::ParseState)
    return @default ps @nocloser ps :inwhere parse_barray(ps)
end


function parse_barray(ps::ParseState)
    args = EXPR[]
    trivia = EXPR[EXPR(ps)]

    if kindof(ps.nt) === Tokens.RBRACE
        accept_rbrace(ps, trivia)
        ret = EXPR(:Braces, args, trivia)
    else
        first_arg = @nocloser ps :newline @closebrace ps  @closer ps :ws @closer ps :wsop @closer ps :comma parse_expression(ps)
        if kindof(ps.nt) === Tokens.RBRACE
            push!(args, first_arg)
            if kindof(ps.ws) == SemiColonWS
                pushfirst!(args, EXPR(:Parameters, EXPR[], nothing))
            end
            accept_rbrace(ps, trivia)
            ret = EXPR(:Braces, args, trivia)
        elseif iscomma(ps.nt)
            push!(args, first_arg)
            accept_comma(ps, trivia)
            @closebrace ps parse_comma_sep(ps, args, trivia, true, insertfirst = true)
            accept_rbrace(ps, trivia)
            return EXPR(:Braces, args, trivia)
        elseif kindof(ps.ws) == NewLineWS
            ret = EXPR(:BracesCat, args, trivia)
            push!(ret, first_arg)
            while kindof(ps.nt) != Tokens.RBRACE && kindof(ps.nt) !== Tokens.ENDMARKER
                a = @closebrace ps  parse_expression(ps)
                push!(ret, a)
            end
            pushtotrivia!(ret, accept_rbrace(ps))
            return ret
        elseif kindof(ps.ws) == WS || kindof(ps.ws) == SemiColonWS
            first_row = EXPR(:Row, EXPR[first_arg])
            while kindof(ps.nt) !== Tokens.RBRACE && kindof(ps.ws) !== NewLineWS && kindof(ps.ws) !== SemiColonWS && kindof(ps.nt) !== Tokens.ENDMARKER
                a = @closebrace ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                push!(first_row, a)
            end
            if kindof(ps.nt) === Tokens.RBRACE && kindof(ps.ws) != SemiColonWS
                if length(first_row.args) == 1
                    first_row = EXPR(:BracesCat, first_row.args)
                end
                push!(args, first_row)
                push!(trivia, INSTANCE(next(ps)))
                return EXPR(:BracesCat, args, trivia)
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row = EXPR(:Row, first_row.args)
                end
                ret = EXPR(:BracesCat, EXPR[first_row], trivia)
                while kindof(ps.nt) != Tokens.RBRACE
                    if kindof(ps.nt) === Tokens.ENDMARKER
                        break
                    end
                    first_arg = @closebrace ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                    push!(ret, EXPR(:Row, EXPR[first_arg]))
                    while kindof(ps.nt) !== Tokens.RBRACE && kindof(ps.ws) !== NewLineWS && kindof(ps.ws) !== SemiColonWS && kindof(ps.nt) !== Tokens.ENDMARKER
                        a = @closebrace ps @closer ps :ws @closer ps :wsop parse_expression(ps)
                        push!(last(ret.args), a)
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = setparent!(ret.args[end].args[1], ret)
                    end
                    update_span!(ret)
                end
                pushtotrivia!(ret, accept_rbrace(ps))
                update_span!(ret)
                return ret
            end
        else
            ret = EXPR(:Braces, args, trivia)
            push!(ret, first_arg)
            pushtotrivia!(ret, accept_rbrace(ps))
        end
    end
    return ret
end
