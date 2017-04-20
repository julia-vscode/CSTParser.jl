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
    puncs = INSTANCE[INSTANCE(ps)]
    format_lbracket(ps)

    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(puncs, INSTANCE(ps))
        format_rbracket(ps)

        return EXPR(VECT, [], ps.nt.startbyte - startbyte, puncs)
    else
        @catcherror ps startbyte first_arg = @default ps @nocloser ps newline @closer ps square @closer ps insquare @closer ps ws @closer ps comma parse_expression(ps)

        if ps.nt.kind == Tokens.RSQUARE
            # if first_arg isa EXPR && first_arg.head == TUPLE
            #     first_arg.head = VECT

            #     unshift!(first_arg.punctuation, first(puncs))
            #     next(ps)
            #     push!(first_arg.punctuation, INSTANCE(ps))
            #     format_rbracket(ps)

            #     first_arg.span = ps.nt.startbyte - startbyte
            #     return first_arg
            # elseif first_arg isa EXPR && (first_arg.head == GENERATOR || first_arg.head == FLATTEN)
            if first_arg isa EXPR && (first_arg.head == GENERATOR || first_arg.head == FLATTEN)
                next(ps)
                push!(puncs, INSTANCE(ps))
                format_rbracket(ps)

                if first_arg.args[1] isa EXPR && first_arg.args[1].head isa OPERATOR{1, Tokens.PAIR_ARROW}
                    return EXPR(DICT_COMPREHENSION, [first_arg], ps.nt.startbyte - 
                    startbyte, puncs)
                else
                    return EXPR(COMPREHENSION, [first_arg], ps.nt.startbyte - 
                    startbyte, puncs)
                end
            elseif ps.ws.kind == SemiColonWS
                next(ps)
                push!(puncs, INSTANCE(ps))
                format_rbracket(ps)

                return EXPR(VCAT, [first_arg], ps.nt.startbyte - startbyte, puncs)
            else
                next(ps)
                push!(puncs, INSTANCE(ps))
                format_rbracket(ps)

                ret = EXPR(VECT, [first_arg], ps.nt.startbyte - startbyte, puncs)
            end
        elseif ps.nt.kind == Tokens.COMMA
            ret = EXPR(VECT, [first_arg], -startbyte, puncs)
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            @catcherror ps startbyte @default ps @closer ps square parse_comma_sep(ps, ret, false)

            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            format_rbracket(ps)
            
            if last(ret.args) isa EXPR && last(ret.args).head == PARAMETERS
                ret.head = VCAT
            end

            ret.span = ps.nt.startbyte - startbyte
            return ret
        elseif ps.ws.kind == NewLineWS
            ret = EXPR(VCAT, [first_arg], - startbyte, puncs)
            while ps.nt.kind != Tokens.RSQUARE
                @catcherror ps startbyte a = @default ps @closer ps square parse_expression(ps)
                push!(ret.args, a)
            end
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            format_rbracket(ps)
            
            ret.span += ps.nt.startbyte
            return ret
        elseif ps.ws.kind == WS || ps.ws.kind == SemiColonWS
            first_row = EXPR(HCAT, [first_arg], -(ps.nt.startbyte - first_arg.span))
            while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                @catcherror ps startbyte a = @default ps @closer ps square @closer ps ws parse_expression(ps)
                push!(first_row.args, a)
            end
            first_row.span += ps.nt.startbyte
            if ps.nt.kind == Tokens.RSQUARE
                next(ps)
                push!(puncs, INSTANCE(ps))
                if length(first_row.args) == 1
                    first_row.head == VCAT
                end
                first_row.punctuation = puncs
                first_row.span += first(puncs).span + last(puncs).span
                return first_row
            else
                if length(first_row.args) == 1
                    first_row = first_row.args[1]
                else
                    first_row.head = ROW
                end
                ret = EXPR(VCAT, [first_row], 0)
                while ps.nt.kind != Tokens.RSQUARE
                    @catcherror ps startbyte first_arg = @default ps @closer ps square @closer ps ws parse_expression(ps)
                    push!(ret.args, EXPR(ROW, [first_arg], first_arg.span))
                    while ps.nt.kind != Tokens.RSQUARE && ps.ws.kind != NewLineWS && ps.ws.kind != SemiColonWS
                        @catcherror ps startbyte a = @default ps @closer ps square @closer ps ws parse_expression(ps)
                        push!(last(ret.args).args, a)
                        last(ret.args).span += a.span
                    end
                    # if only one entry dont use :row
                    if length(last(ret.args).args) == 1
                        ret.args[end] = ret.args[end].args[1]
                    end
                end
                next(ps)
                push!(puncs, INSTANCE(ps))
                ret.punctuation = puncs
                ret.span = ps.nt.startbyte - startbyte
                return ret
            end
        end
    end
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
    if ref isa EXPR && ref.head == VECT
        ret = EXPR(REF, [ret, ref.args...], ret.span + ref.span, ref.punctuation)
    elseif ref isa EXPR && ref.head == HCAT
        ret = EXPR(TYPED_HCAT, [ret, ref.args...], ret.span + ref.span, ref.punctuation)
    elseif ref isa EXPR && ref.head == VCAT
        ret = EXPR(TYPED_VCAT, [ret, ref.args...], ret.span + ref.span, ref.punctuation)
    elseif ref isa EXPR && ref.head == COMPREHENSION
        ret = EXPR(TYPED_COMPREHENSION, [ret, ref.args...], ret.span + ref.span, ref.punctuation)
    end
    return ret
end

_start_vect(x::EXPR) = Iterator{:vect}(1, length(x.args) + length(x.punctuation))

_start_vcat(x::EXPR) = Iterator{:vcat}(1, length(x.args) + length(x.punctuation))
_start_hcat(x::EXPR) = Iterator{:hcat}(1, length(x.args) + length(x.punctuation))
_start_row(x::EXPR) = Iterator{:row}(1, length(x.args))

_start_typed_vcat(x::EXPR) = Iterator{:typed_vcat}(1, length(x.args) + length(x.punctuation))


function next(x::EXPR, s::Iterator{:vect})
    if isodd(s.i)
        return x.punctuation[div(s.i + 1, 2)], +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:vcat})
    np = length(x.punctuation) - 2
    if np > 0
        if s.i == s.n
            return last(x.punctuation), +s
        elseif s.i == s.n - 1 
            return last(x.args), +s
        elseif iseven(s.i)
            return x.args[div(s.i, 2)], +s
        else
            return x.punctuation[div(s.i + 1, 2)], +s
        end
    else
        if s.i == 1
            return first(x.punctuation), +s
        elseif s.i == s.n
            return last(x.punctuation), +s
        else
            return x.args[s.i - 1], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:hcat})
    if s.i == 1
        return first(x.punctuation), +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    else
        return x.args[s.i - 1], +s
    end
end

next(x::EXPR, s::Iterator{:row}) = x.args[s.i], +s

function next(x::EXPR, s::Iterator{:typed_vcat})
    if length(x.args) > 0 && last(x.args) isa EXPR && last(x.args).head == PARAMETERS
        if s.i == s.n
            return last(x.punctuation), +s
        elseif s.i == s.n - 1 
            return last(x.args), +s
        elseif s.i == 1
            return x.args[1], +s
        elseif s.i == 2
            return first(x.punctuation), +s
        elseif isodd(s.i)
            return x.args[div(s.i + 1, 2)], +s
        else
            return x.punctuation[div(s.i, 2)], +s
        end
    else
        if s.i == 1
            return x.args[1], +s
        elseif s.i == 2
            return first(x.punctuation), +s
        elseif s.i == s.n
            return last(x.punctuation), +s
        else
            return x.args[s.i - 1], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:typed_hcat})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return first(x.punctuation), +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    else
        return x.args[s.i - 1], +s
    end
end

_start_ref(x::EXPR) = Iterator{:ref}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:ref})
    if  s.i == s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i + 1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end