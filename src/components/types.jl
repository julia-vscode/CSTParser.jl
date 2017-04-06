function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte arg = parse_expression(ps)

    # Linting
    format_typename(ps, arg)

    # Construction
    ret = EXPR(kw, SyntaxNode[arg], ps.nt.startbyte - startbyte)
    ret.defs = [Variable(get_id(arg), :abstract, ret)]

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

# for 0.6 the above two can be merged to a `parse_type` function as 
#  argument orderings will be the same.s

parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPE}}) = parse_struct(ps, TRUE)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}}) = parse_struct(ps, FALSE)

function parse_struct(ps::ParseState, mutable)
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2]

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte sig = @closer ps block @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = parse_block(ps, start_col)

    # Linting
    format_typename(ps, sig)
    T = mutable==TRUE ? Tokens.TYPE : Tokens.IMMUTABLE

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

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
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

function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end
