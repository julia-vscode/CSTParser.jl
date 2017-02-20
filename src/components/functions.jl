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
        push!(ps.current_scope.args, Scope{Tokens.FUNCTION}(sig, []))
    else
        push!(ps.current_scope.args, Scope{Tokens.FUNCTION}(get_id(sig.args[1]), []))
    end
    args = isempty(block.args) ? Expression[sig] : Expression[sig, block]
    return EXPR(kw, args, ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)])
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret)
    start = ps.nt.startbyte
    
    puncs = INSTANCE[INSTANCE(next(ps))]
    format(ps)
    args = @nocloser ps newline @closer ps paren parse_list(ps, puncs)
    push!(puncs, INSTANCE(next(ps)))
    format(ps)
    ret = EXPR(CALL, [ret, args...], ret.span + ps.nt.startbyte - start, puncs)
    return ret
end


_start_function(x::EXPR) = Iterator{:function}(1, 1 + length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:function})
    if s.i == 1
        return x.head, +s
    elseif s.i == s.n
        return x.punctuation[1], +s
    else
        return x.args[s.i - 1], +s
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

