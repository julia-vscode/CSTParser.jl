function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    startbyte = ps.t.startbyte

    # Switch for v0.6 compatability
    if ps.nt.kind == Tokens.TYPE
        # Parsing
        kw1 = INSTANCE(ps)
        format_kw(ps)
        next(ps)
        kw2 = INSTANCE(ps)
        format_kw(ps)

        @catcherror ps startbyte sig = @default ps @closer ps block parse_expression(ps)

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
        push!(ps.diagnostics, Diagnostic{Diagnostics.abstractDeprecation}(startbyte + (0:8), [Diagnostics.TextEdit(ps.t.endbyte + 1:ps.t.endbyte + 1, " end"), Diagnostics.TextEdit(startbyte + (0:kw.span), "abstract type ")]))

        # Construction
        ret = EXPR(kw, SyntaxNode[sig], ps.nt.startbyte - startbyte)
    end
    ret.defs = [Variable(Expr(get_id(sig)), :abstract, ret)]
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    startbyte = ps.t.startbyte
    
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)

    @catcherror ps startbyte arg1 = @default ps @closer ps ws @closer ps wsop parse_expression(ps) 
    @catcherror ps startbyte arg2 = @default ps parse_expression(ps)

    # Linting
    format_typename(ps, arg2)
    push!(ps.diagnostics, Diagnostic{Diagnostics.bitstypeDeprecation}(startbyte + (0:(kw.span + arg1.span + arg2.span)), [Diagnostics.TextEdit(startbyte + (0:(kw.span + arg1.span + arg2.span)), string("primitive type ", Expr(arg2)," ", Expr(arg1), " end"))]))

    # Construction
    ret = EXPR(kw, SyntaxNode[arg1, arg2], ps.nt.startbyte - startbyte, [])
    ret.defs = [Variable(Expr(get_id(arg2)), :bitstype, ret)]

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.PRIMITIVE}})
    startbyte = ps.t.startbyte

    if ps.nt.kind == Tokens.TYPE
        # Parsing
        kw1 = INSTANCE(ps)
        format_kw(ps)
        next(ps)
        kw2 = INSTANCE(ps)
        format_kw(ps)
        @catcherror ps startbyte sig = @default ps @closer ps ws @closer ps wsop parse_expression(ps)
        @catcherror ps startbyte arg = @default ps @closer ps block parse_expression(ps)

        # Construction
        if ps.nt.kind != Tokens.END
            return ERROR{MissingEnd}(ps.nt.startbyte - startbyte, EXPR(kw2, [sig, arg], ps.nt.startbyte - startbyte, [kw1]))
        else
            next(ps)
            ret = EXPR(kw2, [arg, sig], ps.nt.startbyte - startbyte, [kw1, INSTANCE(ps)])
            # ret.defs = [Variable(get_id(sig), :bitstype, ret)]
        end
        ret.defs = [Variable(Expr(get_id(sig)), :bitstype, ret)]
    else
        ret = IDENTIFIER(ps.nt.startbyte - startbyte, :primitive)
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)

    @catcherror ps startbyte arg1 = @closer ps ws @closer ps wsop parse_expression(ps) 
    @catcherror ps startbyte arg2 = parse_expression(ps)

    # Linting
    format_typename(ps, arg1)
    push!(ps.diagnostics, Diagnostic{Diagnostics.typealiasDeprecation}(startbyte + (0:(kw.span + arg1.span + arg2.span)), [Diagnostics.TextEdit(startbyte + (0:(kw.span + arg1.span + arg2.span)), string("const ", Expr(arg1), " = ", Expr(arg2)))]))

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
        format_kw(ps)
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
    format_kw(ps)
    @catcherror ps startbyte sig = @default ps @closer ps block @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    # Linting
    _lint_struct(ps, startbyte, kw, sig, block)

    # Construction
    T = mutable == TRUE ? Tokens.TYPE : Tokens.IMMUTABLE
    next(ps)
    ret = EXPR(kw, SyntaxNode[mutable, sig, block], ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])
    ret.defs = [Variable(Expr(get_id(sig)), Expr(mutable) ? :mutable : :immutable, ret)]

    return ret
end


function _lint_struct(ps::ParseState, startbyte::Int, kw, sig, block)
    format_typename(ps, sig)
    hloc = ps.nt.startbyte - block.span
    for a in block.args
        if a isa EXPR && declares_function(a)
            fname = _get_fname(a.args[1])
            if Expr(fname) != Expr(get_id(sig))
                push!(ps.diagnostics, Diagnostic{Diagnostics.MisnamedConstructor}(hloc + (0:a.span), []))
            end
        else
            id = get_id(a)
            t = get_t(a)
        end
        hloc += a.span
    end
    if kw isa KEYWORD{Tokens.TYPE}
        push!(ps.diagnostics, Diagnostic{Diagnostics.typeDeprecation}(startbyte + (0:kw.span), [Diagnostics.TextEdit(startbyte + (0:kw.span), "mutable struct ")]))
    elseif kw isa KEYWORD{Tokens.IMMUTABLE}
        push!(ps.diagnostics, Diagnostic{Diagnostics.immutableDeprecation}(startbyte + (0:kw.span), [Diagnostics.TextEdit(startbyte + (0:kw.span), "struct ")]))
    end
end

function next(x::EXPR, s::Iterator{:abstract})
    if s.i == 1
        return x.head, next_iter(s)
    elseif s.i == 2
        return x.args[1], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:abstracttype})
    if s.i == 1
        return x.punctuation[1], next_iter(s)
    elseif s.i == 2
        return x.head, next_iter(s)
    elseif s.i == 3
        return x.args[1], next_iter(s)
    elseif s.i == 4
        return x.punctuation[2], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, next_iter(s)
    elseif s.i == 2
        return x.args[1], next_iter(s)
    elseif s.i == 3
        return x.args[2], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:primitivetype})
    if s.i == 1
        return x.punctuation[1], next_iter(s)
    elseif s.i == 2
        return x.head, next_iter(s)
    elseif s.i == 3
        return x.args[2], next_iter(s)
    elseif s.i == 4
        return x.args[1], next_iter(s)
    elseif s.i == 5
        return x.punctuation[2], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:type})
    if s.i == 1
        return x.head, next_iter(s)
    elseif s.i == 2
        return x.args[2], next_iter(s)
    elseif s.i == 3
        return x.args[3], next_iter(s)
    elseif s.i == 4
        return x.punctuation[1], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:struct})
    if s.n == 5
        if s.i == 1
            return x.punctuation[1], next_iter(s)
        elseif s.i == 2
            return x.head, next_iter(s)
        elseif s.i == 3
            return x.args[2], next_iter(s)
        elseif s.i == 4
            return x.args[3], next_iter(s)
        elseif s.i == 5
            return x.punctuation[2], next_iter(s)
        end
    else
        if s.i == 1
            return x.head, next_iter(s)
        elseif s.i == 2
            return x.args[2], next_iter(s)
        elseif s.i == 3
            return x.args[3], next_iter(s)
        elseif s.i == 4
            return x.punctuation[1], next_iter(s)
        end
    end
end

function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, next_iter(s)
    elseif s.i == 2
        return x.args[1], next_iter(s)
    elseif s.i == 3
        return x.args[2], next_iter(s)
    end
end
