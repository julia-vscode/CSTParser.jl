"""
parse_tuple(ps, ret)

`ret` is followed by a comma so tries to parse the rest of the
tuple.
"""
function parse_tuple(ps::ParseState, ret)
    next(ps)
    op = INSTANCE(ps)

    if closer(ps) || (isassignment(ps.nt) && ps.nt.kind != Tokens.APPROX)
        ret = EXPR{TupleH}(Any[ret, op])
    else
        @catcherror ps nextarg = @closer ps tuple parse_expression(ps)
        ret = EXPR{TupleH}(Any[ret, op, nextarg])
    end
    return ret
end

function parse_tuple(ps::ParseState, ret::EXPR{TupleH})
    next(ps)
    op = INSTANCE(ps)

    if closer(ps) || (isassignment(ps.nt) && ps.nt.kind != Tokens.APPROX)
        push!(ret, op)
    else
        @catcherror ps nextarg = @closer ps tuple parse_expression(ps)
        if !(first(ret.args) isa PUNCTUATION{Tokens.LPAREN})
            push!(ret, op)
            push!(ret, nextarg)
        else
            ret = EXPR{TupleH}(Any[ret, op, nextarg])
        end
    end
    return ret
end
"""
    parse_array(ps)
Having hit '[' return either:
+ A vect
+ A vcat
+ A comprehension
+ An array (vcat of hcats)
"""
function parse_array(ps::ParseState)
    args = Any[INSTANCE(ps)]

    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(args, INSTANCE(ps))

        return EXPR{Vect}(args)
    else
        @catcherror ps first_arg = @default ps @nocloser ps newline @closer ps square @closer ps insquare @closer ps ws @closer ps wsop @closer ps comma parse_expression(ps)

        if ps.nt.kind == Tokens.RSQUARE
            if first_arg isa EXPR{Generator} || first_arg isa EXPR{Flatten}
                next(ps)
                push!(args, INSTANCE(ps))

                if first_arg.args[1] isa BinaryOpCall && first_arg.args[2] isa OPERATOR{Tokens.PAIR_ARROW,false}
                    return EXPR{DictComprehension}(Any[args[1], first_arg, INSTANCE(ps)])
                else
                    return EXPR{Comprehension}(Any[args[1], first_arg, INSTANCE(ps)])
                end
            elseif ps.ws.kind == SemiColonWS
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))

                return EXPR{Vcat}(args)
            else
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))

                ret = EXPR{Vect}(args)
            end
        elseif ps.nt.kind == Tokens.COMMA
            etype = Vect
            push!(args, first_arg)
            next(ps)
            push!(args, INSTANCE(ps))
            @catcherror ps @default ps @closer ps square parse_comma_sep(ps, args, false)

            if last(args) isa EXPR{Parameters}
                etype = Vcat
                unshift!(args, pop!(args))
            end
            push!(args, INSTANCE(next(ps)))
            return EXPR{etype}(args)
        elseif ps.ws.kind == NewLineWS
            ret = EXPR{Vcat}(args)
            push!(ret, first_arg)
            while ps.nt.kind != Tokens.RSQUARE
                @catcherror ps a = @default ps @closer ps square parse_expression(ps)
                push!(ret, a)
            end
            next(ps)
            push!(ret, INSTANCE(ps))

            return ret
        elseif ps.ws.kind == WS || ps.ws.kind == SemiColonWS
            first_row = EXPR{Hcat}(Any[first_arg])
            while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                @catcherror ps a = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                push!(first_row, a)
            end
            if ps.nt.kind == Tokens.RSQUARE && ps.ws.kind != SemiColonWS
                if length(first_row.args) == 1
                    first_row = EXPR{Vcat}(first_row.args)
                end
                next(ps)
                push!(first_row, INSTANCE(ps))
                unshift!(first_row, args[1])
                return first_row
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row = EXPR{Row}(first_row.args)
                end
                ret = EXPR{Vcat}(Any[args[1], first_row])
                while ps.nt.kind != Tokens.RSQUARE
                    @catcherror ps first_arg = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                    push!(ret, EXPR{Row}(Any[first_arg]))
                    while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                        @catcherror ps a = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                        push!(last(ret.args), a)
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = ret.args[end].args[1]
                    end
                    update_span!(ret)
                end
                next(ps)
                push!(ret, INSTANCE(ps))
                return ret
            end
        else
            ps.errored = true
            ret = EXPR{ERROR}(Any[INSTANCE(ps)])
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
function parse_ref(ps::ParseState, ret)
    next(ps)
    @catcherror ps ref = parse_array(ps)
    return _parse_ref(ret, ref)
end

function _parse_ref(ret, ref::EXPR{Vect})
    ret = EXPR{Ref}(Any[ret])
    for a in ref.args
        push!(ret, a)
    end
    return ret
end

function _parse_ref(ret, ref::EXPR{Hcat})
    ret = EXPR{TypedHcat}(Any[ret])
    for a in ref.args
        push!(ret, a)
    end
    return ret
end

function _parse_ref(ret, ref::EXPR{Vcat})
    ret = EXPR{TypedVcat}(Any[ret])
    for a in ref.args
        push!(ret, a)
    end
    return ret
end

function _parse_ref(ret, ref)
    ret = EXPR{TypedComprehension}(Any[ret])
    for a in ref.args
        push!(ret, a)
    end
    return ret
end

"""
parse_curly(ps, ret)

Parses the juxtaposition of `ret` with an opening brace. Parses a comma
seperated list.
"""
function parse_curly(ps::ParseState, ret)
    args = Any[ret, INSTANCE(next(ps))]
    @catcherror ps  @default ps @nocloser ps inwhere @closer ps brace parse_comma_sep(ps, args, true, false)
    push!(args, INSTANCE(next(ps)))
    return EXPR{Curly}(args)
end

function parse_cell1d(ps::ParseState)
    ret = EXPR{Cell1d}(Any[INSTANCE(ps)])
    args = Any[INSTANCE(ps)]
    @catcherror ps @default ps @closer ps brace parse_comma_sep(ps, args, true, false)
    push!(args, INSTANCE(next(ps)))
    return EXPR{Cell1d}(args)
end


