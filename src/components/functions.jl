# Functions
#   definition
#   short form definition
#   call

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    sig = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    if sig isa INSTANCE
        push!(ps.current_scope, Declaration{Tokens.FUNCTION}(sig, []))
    else
        push!(ps.current_scope, Declaration{Tokens.FUNCTION}(get_id(sig.args[1]), []))
    end
    return EXPR(kw, Expression[sig, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret)
    start = ps.nt.startbyte
    
    puncs = INSTANCE[INSTANCE(next(ps))]
    args = @nocloser ps newline @closer ps paren parse_list(ps, puncs)
    push!(puncs, INSTANCE(next(ps)))

    ret = EXPR(CALL, [ret, args...], ret.span + ps.ws.endbyte - start + 1, puncs)
    return ret
end


_start_function(x::EXPR) = Iterator{:function}(1, 4)

function next(x::EXPR, s::Iterator{:function})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:call})
    if  s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

