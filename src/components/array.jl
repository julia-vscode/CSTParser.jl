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
    args = EXPR[INSTANCE(ps)]
    format_lbracket(ps)

    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(args, INSTANCE(ps))
        format_rbracket(ps)

        return EXPR{Vect}(args, ps.nt.startbyte - startbyte, Variable[], "")
    else
        @catcherror ps startbyte first_arg = @default ps @nocloser ps newline @closer ps square @closer ps insquare @closer ps ws @closer ps wsop @closer ps comma parse_expression(ps)

        if ps.nt.kind == Tokens.RSQUARE
            if first_arg isa EXPR{Generator} || first_arg isa EXPR{Flatten}
                next(ps)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                if first_arg.args[1] isa EXPR{BinaryOpCall} && first_arg.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.PAIR_ARROW,false}}
                    return EXPR{DictComprehension}(EXPR[args[1], first_arg, INSTANCE(ps)], ps.nt.startbyte - 
                    startbyte, Variable[], "")
                else
                    return EXPR{Comprehension}(EXPR[args[1], first_arg, INSTANCE(ps)], ps.nt.startbyte - 
                    startbyte, Variable[], "")
                end
            elseif ps.ws.kind == SemiColonWS
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                return EXPR{Vcat}(args, ps.nt.startbyte - startbyte, Variable[], "")
            else
                next(ps)
                push!(args, first_arg)
                push!(args, INSTANCE(ps))
                format_rbracket(ps)

                ret = EXPR{Vect}(args, ps.nt.startbyte - startbyte, Variable[], "")
            end
        elseif ps.nt.kind == Tokens.COMMA
            ret = EXPR{Vect}(args, -startbyte, Variable[], "")
            push!(ret.args, first_arg)
            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_comma(ps)
            @catcherror ps startbyte @default ps @closer ps square parse_comma_sep(ps, ret, false)

            
            
            if last(ret.args) isa EXPR{Parameters}
                ret = EXPR{Vcat}(ret.args, 0, Variable[], "")
                unshift!(ret.args, pop!(ret.args))
                # if isempty(last(ret.args).args)
                #     pop!(ret.args)
                # end
            end
            next(ps)
            push!(ret.args, INSTANCE(ps))
            format_rbracket(ps)

            ret.span = ps.nt.startbyte - startbyte
            return ret
        elseif ps.ws.kind == NewLineWS
            ret = EXPR{Vcat}(args, - startbyte, Variable[], "")
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
            first_row = EXPR{Hcat}(EXPR[first_arg], -(ps.nt.startbyte - first_arg.span), Variable[], "")
            while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                @catcherror ps startbyte a = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                push!(first_row.args, a)
            end
            first_row.span += ps.nt.startbyte
            if ps.nt.kind == Tokens.RSQUARE && ps.ws.kind != SemiColonWS
                if length(first_row.args) == 1
                    first_row = EXPR{VCAT}(first_row.args, first_row.span, Variable[], "")
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
                    first_row = EXPR{Row}(first_row.args, first_row.span, Variable[], "")
                end
                ret = EXPR{Vcat}(EXPR[args[1], first_row], 0, Variable[], "")
                while ps.nt.kind != Tokens.RSQUARE
                    @catcherror ps startbyte first_arg = @default ps @closer ps square @closer ps ws @closer ps wsop parse_expression(ps)
                    push!(ret.args, EXPR{Row}(EXPR[first_arg], first_arg.span, Variable[], ""))
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
    ret = EXPR{Ref}(EXPR[ret, ref.args...], ret.span + ref.span, Variable[], "")
    # _lint_hcat(ps, ret)
    return ret
end

function _parse_ref(ret, ref::EXPR{Hcat})
    EXPR{TypedHcat}(EXPR[ret, ref.args...], ret.span + ref.span, Variable[], "")
end

function _parse_ref(ret, ref::EXPR{Vcat})
    EXPR{TypedVcat}(EXPR[ret, ref.args...], ret.span + ref.span, Variable[], "")
end

_parse_ref(ret, ref) = EXPR{TypedComprehension}(EXPR[ret, ref.args...], ret.span + ref.span, Variable[], "")

function _lint_hcat(ps::ParseState, ret)
    if length(ret.args) == 3 && ret.args[3] isa EXPR{Quotenode} && ret.args[3].val isa KEYWORD{Tokens.END}
        push!(ps.diagnostics, Diagnostic{Diagnostics.PossibleTypo}(ps.nt.startbyte + (-ret.span:0), []))
    end
end
