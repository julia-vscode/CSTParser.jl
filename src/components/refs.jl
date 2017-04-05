"""
    parse_ref(ps, ret)

Handles cases where an expression - `ret` - is followed by 
`[`. Parses the following bracketed expression and modifies it's
`.head` appropriately.
"""
function parse_ref(ps::ParseState, ret)
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

_start_ref(x::EXPR) = Iterator{:ref}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:ref})
    if  s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end