"""
    parse_array(ps)
Having hit '[' return either:
+ A vect
+ A vcat
+ A comprehension
+ An array (vcat of hcats)
"""
function parse_array(ps::ParseState)
    startbyte = ps.t.startbyte
    args = SyntaxNode[INSTANCE(ps)]
    format_lbracket(ps)

    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(args, INSTANCE(ps))
        format_rbracket(ps)

        return EXPR(Vect, args, ps.nt.startbyte - startbyte)
    else
        @catcherror ps startbyte first_arg = @default ps @nocloser ps newline @closer ps square @closer ps insquare @closer ps ws @closer ps wsop @closer ps comma parse_expression(ps)

        if ps.nt.kind == Tokens.RSQUARE
            if first_arg isa EXPR{Generator} || first_arg isa EXPR{Flatten}
                next(ps)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                if first_arg.args[1] isa EXPR{BinaryOpCall} && first_arg.args[2].head isa OPERATOR{AssignmentOp,Tokens.PAIR_ARROW}
                    return EXPR(DictComprehension, [args[1], first_arg, INSTANCE(ps)], ps.nt.startbyte - 
                    startbyte)
                else
                    return EXPR(Comprehension, [args[1], first_arg, INSTANCE(ps)], ps.nt.startbyte - 
                    startbyte)
                end
            elseif ps.ws.kind == SemiColonWS
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                return EXPR(Vcat, args, ps.nt.startbyte - startbyte)
            else
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                ret = EXPR(Vect, args, ps.nt.startbyte - startbyte)
            end
        elseif ps.nt.kind == Tokens.COMMA
            ret = EXPR(Vect, args, -startbyte)
            push!(ret.args, first_arg)
            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_comma(ps)
            @catcherror ps startbyte @default ps @closer ps square parse_comma_sep(ps, ret, false)

            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_rbracket(ps)
            
            if last(ret.args) isa EXPR{Parameters}
                ret = EXPR(Vcat, ret.args, 0)
                if isempty(last(ret.args).args)
                    pop!(ret.args)
                end
            end

            ret.span = ps.nt.startbyte - startbyte
            return ret
        elseif ps.ws.kind == NewLineWS
            ret = EXPR(Vcat, args, - startbyte)
            push!(ret.args, first_arg)
            while ps.nt.kind != Tokens.RSQUARE
                @catcherror ps startbyte a = @default ps @closer ps square parse_expression(ps)
                push!(ret.args, a)
            end
            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_rbracket(ps)
            
            ret.span += ps.nt.startbyte
            return ret
        elseif ps.ws.kind == WS || ps.ws.kind == SemiColonWS
            first_row = EXPR(Hcat, [first_arg], -(ps.nt.startbyte - first_arg.span))
            while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                @catcherror ps startbyte a = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                push!(first_row.args, a)
            end
            first_row.span += ps.nt.startbyte
            if ps.nt.kind == Tokens.RSQUARE && ps.ws.kind != SemiColonWS
                if length(first_row.args) == 1
                    first_row.head == VCAT
                end
                next(ps)
                push!(first_row.args, INSTANCE(ps))
                unshift!(first_row.args, args[1])
                first_row.span += first(first_row.args).span + last(first_row.args).span
                return first_row
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row = EXPR(Row, first_row.args, first_row.span)
                end
                ret = EXPR(Vcat, [args[1], first_row], 0)
                while ps.nt.kind != Tokens.RSQUARE
                    @catcherror ps startbyte first_arg = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                    push!(ret.args, EXPR(Row, [first_arg], first_arg.span))
                    while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                        @catcherror ps startbyte a = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                        push!(last(ret.args).args, a)
                        last(ret.args).span += a.span
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = ret.args[end].args[1]
                    end
                end
                next(ps)
                push!(ret.args, INSTANCE(ps))
                ret.span = ps.nt.startbyte - startbyte
                return ret
            end
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
    startbyte = ps.nt.startbyte
    
    next(ps)
    @catcherror ps startbyte ref = parse_array(ps)
    # if ref isa EXPR{Vect}
    #     ret = EXPR(Ref, [ret, ref.args...], ret.span + ref.span)
    # elseif ref isa EXPR{Hcat}
    #     ret = EXPR(TypedHcat, [ret, ref.args...], ret.span + ref.span)
    #     # _lint_hcat(ps, ret)
    # elseif ref isa EXPR{Vcat}
    #     ret = EXPR(TypedVcat, [ret, ref.args...], ret.span + ref.span)
    # else
    #     ret = EXPR(TypedComprehension, [ret, ref.args...], ret.span + ref.span)
    # end
    # return ret
    return _parse_ref(ret, ref)
end

function _parse_ref(ret, ref::EXPR{Vect})
    ret = EXPR(Ref, [ret, ref.args...], ret.span + ref.span)
    # _lint_hcat(ps, ret)
    return ret
end

function _parse_ref(ret, ref::EXPR{Hcat})
    EXPR(TypedHcat, [ret, ref.args...], ret.span + ref.span)
end

function _parse_ref(ret, ref::EXPR{Vcat})
    EXPR(TypedVcat, [ret, ref.args...], ret.span + ref.span)
end

_parse_ref(ret, ref) = EXPR(TypedComprehension, [ret, ref.args...], ret.span + ref.span)

function _lint_hcat(ps::ParseState, ret)
    if length(ret.args) == 3 && ret.args[3] isa QUOTENODE && ret.args[3].val isa KEYWORD{Tokens.END}
        push!(ps.diagnostics, Diagnostic{Diagnostics.PossibleTypo}(ps.nt.startbyte + (-ret.span:0), []))
    end
end


_start_vect(x::EXPR) = Iterator{:vect}(1, length(x.args) + length(x.punctuation))

_start_vcat(x::EXPR) = Iterator{:vcat}(1, length(x.args) + length(x.punctuation))
_start_hcat(x::EXPR) = Iterator{:hcat}(1, length(x.args) + length(x.punctuation))
_start_row(x::EXPR) = Iterator{:row}(1, length(x.args))

_start_typed_vcat(x::EXPR) = Iterator{:typed_vcat}(1, length(x.args) + length(x.punctuation))


function next(x::EXPR, s::Iterator{:vect})
    if isodd(s.i)
        return x.punctuation[div(s.i + 1, 2)], next_iter(s)
    elseif s.i == s.n
        return last(x.punctuation), next_iter(s)
    else
        return x.args[div(s.i, 2)], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:vcat})
    np = length(x.punctuation) - 2
    if np > 0
        if s.i == s.n
            return last(x.punctuation), next_iter(s)
        elseif s.i == s.n - 1 
            return last(x.args), next_iter(s)
        elseif iseven(s.i)
            return x.args[div(s.i, 2)], next_iter(s)
        else
            return x.punctuation[div(s.i + 1, 2)], next_iter(s)
        end
    else
        if s.i == 1
            return first(x.punctuation), next_iter(s)
        elseif s.i == s.n
            return last(x.punctuation), next_iter(s)
        else
            return x.args[s.i - 1], next_iter(s)
        end
    end
end

function next(x::EXPR, s::Iterator{:hcat})
    if s.i == 1
        return first(x.punctuation), next_iter(s)
    elseif s.i == s.n
        return last(x.punctuation), next_iter(s)
    else
        return x.args[s.i - 1], next_iter(s)
    end
end

next(x::EXPR, s::Iterator{:row}) = x.args[s.i], next_iter(s)

function next(x::EXPR, s::Iterator{:typed_vcat})
    if length(x.args) > 0 && last(x.args) isa EXPR && last(x.args).head == PARAMETERS
        if s.i == s.n
            return last(x.punctuation), next_iter(s)
        elseif s.i == s.n - 1 
            return last(x.args), next_iter(s)
        elseif s.i == 1
            return x.args[1], next_iter(s)
        elseif s.i == 2
            return first(x.punctuation), next_iter(s)
        elseif isodd(s.i)
            return x.args[div(s.i + 1, 2)], next_iter(s)
        else
            return x.punctuation[div(s.i, 2)], next_iter(s)
        end
    else
        if s.i == 1
            return x.args[1], next_iter(s)
        elseif s.i == 2
            return first(x.punctuation), next_iter(s)
        elseif s.i == s.n
            return last(x.punctuation), next_iter(s)
        else
            return x.args[s.i - 1], next_iter(s)
        end
    end
end

function next(x::EXPR, s::Iterator{:typed_hcat})
    if s.i == 1
        return x.args[1], next_iter(s)
    elseif s.i == 2
        return first(x.punctuation), next_iter(s)
    elseif s.i == s.n
        return last(x.punctuation), next_iter(s)
    else
        return x.args[s.i - 1], next_iter(s)
    end
end

_start_ref(x::EXPR) = Iterator{:ref}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:ref})
    if s.i == s.n
        return last(x.punctuation), next_iter(s)
    elseif isodd(s.i)
        return x.args[div(s.i + 1, 2)], next_iter(s)
    else
        return x.punctuation[div(s.i, 2)], next_iter(s)
    end
end
