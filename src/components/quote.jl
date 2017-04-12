function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte arg = @default ps parse_block(ps, start_col)
    next(ps)

    # Construction
    ret = EXPR(kw, SyntaxNode[arg], ps.nt.startbyte - startbyte, [INSTANCE(ps)])
    
    return ret
end


function _start_quote(x::EXPR)
    if x.head.span > 0
        return Iterator{:quote}(1, 3)
    else
        return Iterator{:quote}(1, 2)
    end
end

function next(x::EXPR, s::Iterator{:quote})
    if x.head.span > 0
        if s.i == 1
            return x.head, +s
        elseif s.i == s.n
            return last(x.punctuation), +s
        else
            return x.args[1], +s
        end
    else
        if s.i == 1
            return first(x.punctuation), +s
        else
            return x.args[1], +s
        end
    end
end

start(x::QUOTENODE) = Iterator{:quotenode}(1, 1 + length(x.punctuation))
function next(x::QUOTENODE, s::Iterator{:quotenode})
    if isempty(x.punctuation)
        return x.val, +s
    end

    if s.i == 1
        return first(x.punctuation), +s
    else
        return x.val, +s
    end
end

function getindex(x::QUOTENODE, i::Int)
    s = start(x)
    @assert i <= s.n
    s.i = i
    next(x, s)[1]
end