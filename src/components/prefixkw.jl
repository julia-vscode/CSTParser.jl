function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    return EXPR(kw, [arg], ps.nt.startbyte - start)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    if arg isa EXPR && arg.head isa KEYWORD{Tokens.CONST}
        ret = EXPR(arg.head, [arg], ps.nt.startbyte - start)
        arg.head = kw
    else
        if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
            ret = EXPR(kw, [arg.args...], ps.nt.startbyte - start, arg.punctuation)
        else
            ret = EXPR(kw, [arg], ps.nt.startbyte - start)
        end
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @default ps parse_expression(ps)
    if arg isa EXPR && arg.head isa KEYWORD{Tokens.CONST}
        ret = EXPR(arg.head, [arg], ps.nt.startbyte - start)
        arg.head = kw
    else
        if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
            ret = EXPR(kw, [arg.args...], ps.nt.startbyte - start, arg.punctuation)
        else
            ret = EXPR(kw, [arg], ps.nt.startbyte - start)
        end
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    args = @default ps SyntaxNode[closer(ps) ? NOTHING : parse_expression(ps)]
    return  EXPR(kw, args, ps.nt.startbyte - start)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    # if ps.closer.square
        return IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, ps.t.startbyte, :end)
    # else
    #     error("unexpected `end`")
    # end
end

function next(x::EXPR, s::Iterator{:const})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:global})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:local})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:return})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end