function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    start = ps.t.startbyte
    
    # Parsing
    kw = INSTANCE(ps)
    arg = parse_expression(ps)

    # Construction 
    ret = EXPR(kw, [arg], ps.nt.startbyte - start)

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    arg = parse_expression(ps)

    # Construction
    if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
        ret = EXPR(kw, [arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    else
        ret = EXPR(kw, [arg], ps.nt.startbyte - startbyte)
    end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    arg = @default ps parse_expression(ps)

    # Construction
    if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
        ret = EXPR(kw, [arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    else
        ret = EXPR(kw, [arg], ps.nt.startbyte - startbyte)
    end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    args = @default ps SyntaxNode[closer(ps) ? NOTHING : parse_expression(ps)]

    # Construction
    ret = EXPR(kw, args, ps.nt.startbyte - startbyte)
    
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    return IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :end)
end

function next(x::EXPR, s::Iterator{:const})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:local})
    if s.i == 1
        return x.head, +s
    elseif iseven(s.i)
        return x.args[div(s.i, 2)], +s
    else
        return x.punctuation[div(s.i - 1, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:return})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end