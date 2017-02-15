function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    push!(ps.current_scope, Declaration{Tokens.ABSTRACT}(get_id(arg), []))
    return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)
    push!(ps.current_scope, Declaration{Tokens.BITSTYPE}(get_id(arg2), []))
    return EXPR(kw, Expression[arg1, arg2], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)
    push!(ps.current_scope, Declaration{Tokens.TYPEALIAS}(get_id(arg1), []))
    return EXPR(kw, Expression[arg1, arg2], ps.ws.endbyte - start + 1)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    push!(ps.current_scope, Declaration{Tokens.TYPE}(get_id(arg), []))
    return EXPR(kw, Expression[TRUE, arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    push!(ps.current_scope, Declaration{Tokens.IMMUTABLE}(get_id(arg), []))

    return EXPR(kw, Expression[FALSE, arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
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



get_id{K}(x::INSTANCE{IDENTIFIER,K}) = x

function get_id(x::EXPR)
    if x.head isa INSTANCE{OPERATOR{6}, Tokens.ISSUBTYPE}
        return get_id(x.args[1])
    elseif x.head == CURLY
        return get_id(x.args[1])
    else
        error("couldn't find identifier name of $x")
    end
end