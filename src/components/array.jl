"""
    parse_array(ps)
Having hit '[' return either:
+ A vect
+ A vcat
+ A comprehension
+ An array (vcat of hcats)
"""
function parse_array(ps::ParseState)
    start = ps.t.startbyte
    puncs = INSTANCE[INSTANCE(ps)]
    format(ps)
    if ps.nt.kind == Tokens.RSQUARE
        next(ps)
        push!(puncs, INSTANCE(ps))
        format(ps)
        return EXPR(VECT, [], ps.nt.startbyte - start, puncs)
    else
        first_arg = @default ps @nocloser ps newline @closer ps square @closer ps ws parse_expression(ps)

        # Handle macros
        if first_arg isa LITERAL{Tokens.MACRO}
            first_arg = EXPR(MACROCALL, [first_arg], first_arg.span)
            @default ps @closer ps square while !closer(ps)
                a = @closer ps ws parse_expression(ps)
                push!(first_arg.args, a)
                first_arg.span += a.span
            end
        end
        
        if ps.nt.kind == Tokens.RSQUARE
            if first_arg isa EXPR && first_arg.head == TUPLE
                first_arg.head = VECT
                unshift!(first_arg.punctuation, first(puncs))
                next(ps)
                push!(first_arg.punctuation, INSTANCE(ps))
                first_arg.span += first(first_arg.punctuation).span
                first_arg.span += last(first_arg.punctuation).span
                return first_arg
            elseif first_arg isa EXPR && first_arg.head == GENERATOR
                next(ps)
                push!(puncs, INSTANCE(ps))
                return EXPR(COMPREHENSION, [first_arg], ps.nt.startbyte - start, puncs)
            else
                next(ps)
                push!(puncs, INSTANCE(ps))
                ret = EXPR(VECT, [first_arg], ps.nt.startbyte - start, puncs)
            end
        elseif ps.ws.kind == SemiColonWS
            ret = EXPR(VCAT,[first_arg], -start, puncs)
            @default ps @closer ps square @closer ps ws @closer ps comma while ps.ws.kind == SemiColonWS
                if ps.nt.kind == Tokens.COMMA
                    error("unexpected comma in matrix expression")
                end
                arg = parse_expression(ps)
                push!(ret.args, arg)
            end
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            ret.span = ps.nt.startbyte - start
            return ret
        end
    end
end

_start_vect(x::EXPR) = Iterator{:vect}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:vect})
    if isodd(s.i)
        return x.punctuation[div(s.i + 1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end