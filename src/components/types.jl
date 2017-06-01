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
        next(ps)
        ret = EXPR{Abstract}(EXPR[kw1, kw2, sig, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
    else
        # Parsing
        kw = INSTANCE(ps)
        @catcherror ps startbyte sig = @default ps parse_expression(ps)

        # Linting
        # format_typename(ps, sig)
        push!(ps.diagnostics, Diagnostic{Diagnostics.abstractDeprecation}(startbyte + (0:8), [Diagnostics.TextEdit(ps.t.endbyte + 1:ps.t.endbyte + 1, " end"), Diagnostics.TextEdit(startbyte + (0:kw.span), "abstract type ")], "This specification for abstract types is deprecated"))

        # Construction
        ret = EXPR{Abstract}(EXPR[kw, sig], ps.nt.startbyte - startbyte, Variable[], "")
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
    # format_typename(ps, arg2)
    push!(ps.diagnostics, Diagnostic{Diagnostics.bitstypeDeprecation}(startbyte + (0:(kw.span + arg1.span + arg2.span)), [Diagnostics.TextEdit(startbyte + (0:(kw.span + arg1.span + arg2.span)), string("primitive type ", Expr(arg2)," ", Expr(arg1), " end"))], "This specification for primitive types is deprecated"))

    # Construction
    ret = EXPR{Bitstype}(EXPR[kw, arg1, arg2], ps.nt.startbyte - startbyte, Variable[], "")
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
        next(ps)
        ret = EXPR{Primitive}(EXPR[kw1, kw2, sig, arg, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")

        ret.defs = [Variable(Expr(get_id(sig)), :bitstype, ret)]
    else
        ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - startbyte, Variable[], "primitive")
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
    push!(ps.diagnostics, Diagnostic{Diagnostics.typealiasDeprecation}(startbyte + (0:(kw.span + arg1.span + arg2.span)), [Diagnostics.TextEdit(startbyte + (0:(kw.span + arg1.span + arg2.span)), string("const ", Expr(arg1), " = ", Expr(arg2)))], "This specification for type aliases is deprecated"))

    return EXPR{TypeAlias}(EXPR[kw, arg1, arg2], ps.nt.startbyte - startbyte, Variable[], "")
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
        unshift!(ret.args, kw)
        ret.span += kw.span
    else
        ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "mutable")
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
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, block, start_col)

    # Linting
    _lint_struct(ps, startbyte, kw, sig, block)

    # Construction
    T = mutable == TRUE ? Tokens.TYPE : Tokens.IMMUTABLE
    next(ps)
    ret = EXPR{mutable == TRUE ? Mutable : Struct}(EXPR[kw, sig, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
    ret.defs = [Variable(Expr(get_id(sig)), Expr(mutable) ? :mutable : :immutable, ret)]

    return ret
end


function _lint_struct(ps::ParseState, startbyte::Int, kw, sig, block)
    format_typename(ps, sig)
    hloc = ps.nt.startbyte - block.span
    for a in block.args
        if declares_function(a)
            fname = _get_fname(_get_fsig(a))
            if Expr(fname) != Expr(get_id(sig))
                push!(ps.diagnostics, Diagnostic{Diagnostics.MisnamedConstructor}(hloc + (0:a.span), [], "Constructor name does not match type name"))
            end
        else
            id = get_id(a)
            t = get_t(a)
        end
        hloc += a.span
    end
    if kw isa EXPR{KEYWORD{Tokens.TYPE}}
        push!(ps.diagnostics, Diagnostic{Diagnostics.typeDeprecation}(startbyte + (0:kw.span), [Diagnostics.TextEdit(startbyte + (0:kw.span), "mutable struct ")], "Use of deprecated `type` syntax"))
    elseif kw isa EXPR{KEYWORD{Tokens.IMMUTABLE}}
        push!(ps.diagnostics, Diagnostic{Diagnostics.immutableDeprecation}(startbyte + (0:kw.span), [Diagnostics.TextEdit(startbyte + (0:kw.span), "struct ")], "Use of deprecated `immutable` syntax"))
    end
end
