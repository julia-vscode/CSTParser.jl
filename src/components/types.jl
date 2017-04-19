function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    startbyte = ps.t.startbyte

    # Switch for v0.6 compatability
    if ps.nt.kind == Tokens.TYPE && false
        # Parsing
        kw1 = INSTANCE(ps)
        next(ps)
        kw2 = INSTANCE(ps)
        @catcherror ps startbyte sig = @closer ps block parse_expression(ps)

        # Construction
        if ps.nt.kind != Tokens.END
            return ERROR{MissingEnd}(ps.nt.startbyte - startbyte, EXPR(kw2, [sig], ps.nt.startbyte - startbyte, [kw1]))
        end
        next(ps)
        ret = EXPR(kw2, [sig], ps.nt.startbyte - startbyte, [kw1, INSTANCE(ps)])
    else
        # Parsing
        kw = INSTANCE(ps)
        @catcherror ps startbyte sig = @default ps parse_expression(ps)

        # Linting
        format_typename(ps, sig)

        # Construction
        ret = EXPR(kw, SyntaxNode[sig], ps.nt.startbyte - startbyte)
    end
    ret.defs = [Variable(get_id(sig), :abstract, ret)]
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    startbyte = ps.t.startbyte
    
    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte arg1 = @closer ps ws parse_expression(ps) 
    @catcherror ps startbyte arg2 = parse_expression(ps)

    # Linting
    format_typename(ps, arg2)

    # Construction
    ret = EXPR(kw, SyntaxNode[arg1, arg2], ps.nt.startbyte - startbyte, [])
    ret.defs = [Variable(get_id(arg2), :bitstype, ret)]

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.PRIMITIVE}})
    startbyte = ps.t.startbyte

    if ps.nt.kind == Tokens.TYPE
        # Parsing
        kw1 = INSTANCE(ps)
        next(ps)
        kw2 = INSTANCE(ps)
        @catcherror ps startbyte sig = @closer ps ws parse_expression(ps)
        @catcherror ps startbyte arg = @closer ps block parse_expression(ps)

        # Construction
        if ps.nt.kind != Tokens.END
            return ERROR{MissingEnd}(ps.nt.startbyte - startbyte, EXPR(kw2, [sig, arg], ps.nt.startbyte - startbyte, [kw1]))
        end
        next(ps)
        ret = EXPR(kw2, [arg, sig], ps.nt.startbyte - startbyte, [kw1, INSTANCE(ps)])
        ret.defs = [Variable(get_id(sig), :bitstype, ret)]
    else
        ret = IDENTIFIER(ps.nt.startbyte - startbyte, :primitive)
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte arg1 = @closer ps ws parse_expression(ps) 
    @catcherror ps startbyte arg2 = parse_expression(ps)

    # Linting
    format_typename(ps, arg1)

    return EXPR(kw, SyntaxNode[arg1, arg2], ps.nt.startbyte - startbyte, [])
end

parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPE}}) = parse_struct(ps, TRUE)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}}) = parse_struct(ps, FALSE)

# new 0.6 syntax
parse_kw(ps::ParseState, ::Type{Val{Tokens.STRUCT}}) = parse_struct(ps, FALSE)

function parse_kw(ps::ParseState, ::Type{Val{Tokens.MUTABLE}})
    startbyte = ps.t.startbyte
    
    if ps.nt.kind == Tokens.STRUCT
        kw = INSTANCE(ps)
        next(ps)
        @catcherror ps startbyte ret = parse_struct(ps, TRUE)
        unshift!(ret.punctuation, kw)
        ret.span += kw.span
    else
        ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :mutable)
    end
    return ret
end


function parse_struct(ps::ParseState, mutable)
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte sig = @default ps @closer ps block @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    # Linting
    format_typename(ps, sig)
    T = mutable == TRUE ? Tokens.TYPE : Tokens.IMMUTABLE

    for a in block.args
        if declares_function(a)
        else
            id = get_id(a)
            t = get_t(a)
        end
    end

    # Construction
    next(ps)
    ret = EXPR(kw, SyntaxNode[mutable, sig, block], ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])
    ret.defs = [Variable(Expr(get_id(sig)), Expr(mutable) ? :mutable : :immutable, ret)]

    return ret
end

function next(x::EXPR, s::Iterator{:abstract})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:abstracttype})
    if s.i == 1
        return x.punctuation[1], +s
    elseif s.i == 2
        return x.head, +s
    elseif s.i == 3
        return x.args[1], +s
    elseif s.i == 4
        return x.punctuation[2], +s
    end
end

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:primitivetype})
    if s.i == 1
        return x.punctuation[1], +s
    elseif s.i == 2
        return x.head, +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.args[1], +s
    elseif s.i == 5
        return x.punctuation[2], +s
    end
end

function next(x::EXPR, s::Iterator{:type})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:struct})
    if s.n == 5
        if s.i == 1
            return x.punctuation[1], +s
        elseif s.i == 2
            return x.head, +s
        elseif s.i == 3
            return x.args[2], +s
        elseif s.i == 4
            return x.args[3], +s
        elseif s.i == 5
            return x.punctuation[2], +s
        end
    else
        if s.i == 1
            return x.head, +s
        elseif s.i == 2
            return x.args[2], +s
        elseif s.i == 3
            return x.args[3], +s
        elseif s.i == 4
            return x.punctuation[1], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end
