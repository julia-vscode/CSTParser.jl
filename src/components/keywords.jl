function parse_kw(ps::ParseState)
    k = kindof(ps.t)
    if k == Tokens.IF
        return @default ps @closer ps block parse_if(ps)
    elseif k == Tokens.LET
        return @default ps @closer ps block parse_let(ps)
    elseif k == Tokens.TRY
        return @default ps @closer ps block parse_try(ps)
    elseif k == Tokens.FUNCTION
        return setbinding!(@default ps @closer ps block parse_function(ps))
    elseif k == Tokens.MACRO
        return setbinding!(@default ps @closer ps block parse_macro(ps))
    elseif k == Tokens.BEGIN
        return @default ps @closer ps block parse_begin(ps)
    elseif k == Tokens.QUOTE
        return @default ps @closer ps block parse_quote(ps)
    elseif k == Tokens.FOR
        return @default ps @closer ps block parse_for(ps)
    elseif k == Tokens.WHILE
        return @default ps @closer ps block parse_while(ps)
    elseif k == Tokens.BREAK
        return INSTANCE(ps)
    elseif k == Tokens.CONTINUE
        return INSTANCE(ps)
    elseif k == Tokens.IMPORT
        return parse_imports(ps)
    elseif k == Tokens.IMPORTALL
        return parse_imports(ps)
    elseif k == Tokens.USING
        return parse_imports(ps)
    elseif k == Tokens.EXPORT
        return parse_export(ps)
    elseif k == Tokens.MODULE || k == Tokens.BAREMODULE
        return setbinding!(@default ps @closer ps block parse_module(ps))
    elseif k == Tokens.CONST
        return @default ps parse_const(ps)
    elseif k == Tokens.GLOBAL
        return @default ps parse_global(ps)
    elseif k == Tokens.LOCAL
        return @default ps parse_local(ps)
    elseif k == Tokens.RETURN
        return @default ps parse_return(ps)
    elseif k == Tokens.END
        if ps.closer.square
            ret = mKEYWORD(ps)
        else
            ret = mErrorToken(mIDENTIFIER(ps), UnexpectedToken)
            ps.errored = true
        end
        
        return ret
    elseif k == Tokens.ELSE || k == Tokens.ELSEIF || k == Tokens.CATCH || k == Tokens.FINALLY
        ps.errored = true
        return mErrorToken(mIDENTIFIER(ps), UnexpectedToken)
    elseif k == Tokens.ABSTRACT
        return @default ps parse_abstract(ps)
    elseif k == Tokens.PRIMITIVE
        return @default ps parse_primitive(ps)
    elseif k == Tokens.TYPE
        return mIDENTIFIER(ps)
    elseif k == Tokens.STRUCT
        return setbinding!(@default ps @closer ps block parse_struct(ps, false))
    elseif k == Tokens.MUTABLE
        return setbinding!(@default ps @closer ps block parse_mutable(ps))
    elseif k == Tokens.OUTER
        return mIDENTIFIER(ps)
    else
        ps.errored = true
        return mErrorToken(Unknown)
    end
end
# Prefix 

function parse_const(ps::ParseState)
    kw = mKEYWORD(ps)
    arg = parse_expression(ps)
    if !((typof(arg) === BinaryOpCall && kindof(arg.args[2]) === Tokens.EQ) || (typof(arg) === Global && typof(arg.args[2]) === BinaryOpCall && kindof(arg.args[2].args[2]) === Tokens.EQ))
        ps.errored = true
        arg = mErrorToken(arg, ExpectedAssignment)
    end
    ret = EXPR(Const, EXPR[kw, arg])
    return ret
end

function parse_global(ps::ParseState)
    kw = mKEYWORD(ps)
    arg = parse_expression(ps)

    return EXPR(Global, EXPR[kw, arg])
end

function parse_local(ps::ParseState)
    kw = mKEYWORD(ps)
    arg = parse_expression(ps)

    return EXPR(Local, EXPR[kw, arg])
end

function parse_return(ps::ParseState)
    kw = mKEYWORD(ps)
    args = closer(ps) ? NOTHING() : parse_expression(ps)

    return EXPR(Return, EXPR[kw, args])
end


# One line

@addctx :abstract function parse_abstract(ps::ParseState)
    # Switch for v0.6 compatability
    if kindof(ps.nt) == Tokens.TYPE
        kw1 = mKEYWORD(ps)
        kw2 = mKEYWORD(next(ps))
        sig = @closer ps block parse_expression(ps)
        markparameters!(sig)
        ret = setbinding!(setscope!(EXPR(Abstract, EXPR[kw1, kw2, sig, accept_end(ps)])))
    else
        ret = mIDENTIFIER(ps)
    end
    return ret
end

@addctx :primitive function parse_primitive(ps::ParseState)
    if kindof(ps.nt) == Tokens.TYPE
        kw1 = mKEYWORD(ps)
        kw2 = mKEYWORD(next(ps))
        sig = @closer ps ws @closer ps wsop parse_expression(ps)
        markparameters!(sig)
        arg = @closer ps block parse_expression(ps)

        ret = setbinding!(setscope!(EXPR(Primitive, EXPR[kw1, kw2, sig, arg, accept_end(ps)])))
    else
        ret = mIDENTIFIER(ps)
    end
    return ret
end

function parse_imports(ps::ParseState)
    kw = mKEYWORD(ps)
    kwt = is_import(kw) ? Import :
          is_importall(kw) ? ImportAll :
          Using
    tk = kindof(ps.t)

    arg = parse_dot_mod(ps)

    if kindof(ps.nt) != Tokens.COMMA && kindof(ps.nt) != Tokens.COLON
        ret = EXPR(kwt, vcat(kw, arg))
    elseif kindof(ps.nt) == Tokens.COLON
        ret = EXPR(kwt, vcat(kw, arg))
        push!(ret, mOPERATOR(next(ps)))

        arg = parse_dot_mod(ps, true)
        append!(ret, arg)
        while kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, ret)
            arg = parse_dot_mod(ps, true)
            append!(ret, arg)
        end
    else
        ret = EXPR(kwt, vcat(kw, arg))
        while kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, ret)
            arg = parse_dot_mod(ps)
            append!(ret, arg)
        end
    end

    return ret
end

function parse_export(ps::ParseState)
    args = EXPR[mKEYWORD(ps)]
    append!(args, parse_dot_mod(ps))

    while kindof(ps.nt) == Tokens.COMMA
        push!(args, mPUNCTUATION(next(ps)))
        arg = parse_dot_mod(ps)[1]
        push!(args, arg)
    end

    return EXPR(Export, args)
end


# Block

@addctx :begin function parse_begin(ps::ParseState)
    sb = ps.t.startbyte
    kw = mKEYWORD(ps)
    blockargs = parse_block(ps, EXPR[], (Tokens.END,), true)
    if isempty(blockargs)
        block = EXPR(Block, blockargs, 0, 0)
    else
        fullspan = ps.nt.startbyte - sb - kw.fullspan
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
    end
    ender = accept_end(ps)
    fullspan1 = ps.nt.startbyte - sb
    return EXPR(Begin, EXPR[kw, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span)
end

@addctx :quote function parse_quote(ps::ParseState)
    kw = mKEYWORD(ps)
    blockargs = parse_block(ps)
    return EXPR(Quote, EXPR[kw, EXPR(Block, blockargs), accept_end(ps)])
end

@addctx :function function parse_function(ps::ParseState)
    kw = mKEYWORD(ps)
    sig = @closer ps inwhere @closer ps ws parse_expression(ps)
    if typof(sig) === InvisBrackets && !(typof(sig.args[2]) === TupleH || (typof(sig.args[2]) === Block) || (typof(sig.args[2]) === UnaryOpCall && kindof(sig.args[2].args[2]) === Tokens.DDDOT))
        istuple = true
        sig = EXPR(TupleH, sig.args)
    elseif typof(sig) === TupleH
        istuple = true
    else
        istuple = false
    end

    while kindof(ps.nt) == Tokens.WHERE && kindof(ps.ws) != Tokens.NEWLINE_WS
        # sig = @closer ps inwhere @closer ps ws parse_compound(ps, sig)
        sig = @closer ps inwhere @closer ps ws parse_operator_where(ps, sig, INSTANCE(next(ps)), false)
    end
    mark_sig_args!(sig)
    blockargs = parse_block(ps)

    if isempty(blockargs)
        if typof(sig) === Call || typof(sig) === WhereOpCall || (typof(sig) === BinaryOpCall && !is_exor(sig.args[1])) || istuple || (typof(sig) === InvisBrackets && typof(sig.args[2]) === Block)
            args = EXPR[sig, EXPR(Block, blockargs)]
        else
            args = EXPR[sig]
        end
    else
        args = EXPR[sig, EXPR(Block, blockargs)]
    end

    ret = EXPR(FunctionDef, EXPR[kw])
    for a in args
        push!(ret, a)
    end
    accept_end(ps, ret)
    return setscope!(ret)
end

@addctx :macro function parse_macro(ps::ParseState)
    sb  = ps.t.startbyte
    kw = mKEYWORD(ps)
    sig = @closer ps inwhere @closer ps ws parse_expression(ps)
    mark_sig_args!(sig)
    sb1  = ps.nt.startbyte
    blockargs = parse_block(ps)

    if isidentifier(sig)
        ender = accept_end(ps)
        fullspan1 = ps.nt.startbyte - sb
        ret = EXPR(Macro, EXPR[kw, sig, ender], fullspan1, fullspan1 - ender.fullspan + ender.span)
    elseif isempty(blockargs)
        ender = accept_end(ps)
        fullspan1 = ps.nt.startbyte - sb
        ret = EXPR(Macro, EXPR[kw, sig, EXPR(Block, EXPR[]), ender], fullspan1, fullspan1 - ender.fullspan + ender.span)
    else
        fullspan = ps.nt.startbyte - sb1
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
        ender = accept_end(ps)
        fullspan1 = ps.nt.startbyte - sb
        ret = EXPR(Macro, EXPR[kw, sig, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span)
    end
    return setscope!(ret)
end

# loops
@addctx :for function parse_for(ps::ParseState)
    sb  = ps.t.startbyte
    kw = mKEYWORD(ps)
    ranges = parse_ranges(ps)
    sb1  = ps.nt.startbyte
    blockargs = parse_block(ps)

    if isempty(blockargs)
        block = EXPR(Block, blockargs, 0, 0)
    else
        fullspan = ps.nt.startbyte - sb1
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
    end
    ender = accept_end(ps)
    fullspan1 = ps.nt.startbyte - sb
    return setscope!(EXPR(For, EXPR[kw, ranges, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span))
end

@addctx :while function parse_while(ps::ParseState)
    sb = ps.t.startbyte
    kw = mKEYWORD(ps)
    cond = @closer ps ws parse_expression(ps)
    sb1 = ps.nt.startbyte
    blockargs = parse_block(ps)

    if isempty(blockargs)
        block = EXPR(Block, blockargs, 0, 0)
    else
        fullspan = ps.nt.startbyte - sb1
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
    end
    ender = accept_end(ps)
    fullspan1 = ps.nt.startbyte - sb
    return setscope!(EXPR(While, EXPR[kw, cond, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span))
end

# control flow

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
@addctx :if function parse_if(ps::ParseState, nested = false)
    # Parsing
    kw = mKEYWORD(ps)
    if kindof(ps.ws) == NewLineWS || kindof(ps.ws) == SemiColonWS
        ps.errored = true
        cond = mErrorToken(MissingConditional)
    else
        cond = @closer ps ws parse_expression(ps)
    end
    ifblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.ELSE, Tokens.ELSEIF))

    if nested
        ret = EXPR(If, EXPR[cond, EXPR(Block, ifblockargs)])
    else
        ret = EXPR(If, EXPR[kw, cond, EXPR(Block, ifblockargs)])
    end

    elseblockargs = EXPR[]
    if kindof(ps.nt) == Tokens.ELSEIF
        push!(ret, mKEYWORD(next(ps)))
        push!(elseblockargs, parse_if(ps, true))
    end
    elsekw = kindof(ps.nt) == Tokens.ELSE
    if kindof(ps.nt) == Tokens.ELSE
        push!(ret, mKEYWORD(next(ps)))
        parse_block(ps, elseblockargs)
    end

    # Construction
    if !(isempty(elseblockargs) && !elsekw)
        push!(ret, EXPR(Block, elseblockargs))
    end
    !nested && accept_end(ps, ret)

    return ret
end

function is_wrapped_assignment(x::EXPR)
    if is_assignment(x)
        return true
    elseif typof(x) === CSTParser.InvisBrackets && x.args isa Vector{EXPR} && length(x.args) == 3
        return is_wrapped_assignment(x.args[2])
    end
    return false
end

@addctx :let function parse_let(ps::ParseState)
    args = EXPR[mKEYWORD(ps)]
    if !(kindof(ps.ws) == NewLineWS || kindof(ps.ws) == SemiColonWS)
        arg = @closer ps comma @closer ps ws  parse_expression(ps)
        if kindof(ps.nt) == Tokens.COMMA || !(is_wrapped_assignment(arg) || typof(arg) === IDENTIFIER)
            arg = EXPR(Block, EXPR[arg])
            while kindof(ps.nt) == Tokens.COMMA
                accept_comma(ps, arg)
                startbyte = ps.nt.startbyte
                nextarg = @closer ps comma @closer ps ws parse_expression(ps)
                push!(arg, nextarg)
            end
        end
        push!(args, arg)
    end
    
    blockargs = parse_block(ps)
    push!(args, EXPR(Block, blockargs))
    accept_end(ps, args)

    return setscope!(EXPR(Let, args))
end

@addctx :try function parse_try(ps::ParseState)
    kw = mKEYWORD(ps)
    ret = EXPR(Try, EXPR[kw])

    tryblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.CATCH, Tokens.FINALLY))
    push!(ret, EXPR(Block, tryblockargs))

    #  catch block
    if kindof(ps.nt) == Tokens.CATCH
        next(ps)
        push!(ret, mKEYWORD(ps))
        # catch closing early
        if kindof(ps.nt) == Tokens.FINALLY || kindof(ps.nt) == Tokens.END
            caught = FALSE()
            catchblock = EXPR(Block, EXPR[])
        else
            if kindof(ps.ws) == SemiColonWS || kindof(ps.ws) == NewLineWS
                caught = FALSE()
            else
                caught = @closer ps ws parse_expression(ps)
                setbinding!(caught)
            end
            
            catchblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.FINALLY))
            if !(isidentifier(caught) || kindof(caught) == Tokens.FALSE || (typof(caught) === UnaryOpCall && isoperator(caught.args[1]) && kindof(caught.args[1]) == Tokens.EX_OR))
                pushfirst!(catchblockargs, caught)
                caught = FALSE()
            end
            catchblock = EXPR(Block, catchblockargs)
        end
    else
        caught = FALSE()
        catchblock = EXPR(Block, EXPR[])
    end
    push!(ret, caught)
    push!(ret, catchblock)

    # finally block
    if kindof(ps.nt) == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[4] = setparent!(FALSE(), ret)
        end
        push!(ret, mKEYWORD(next(ps)))
        finallyblockargs = parse_block(ps)
        push!(ret, EXPR(Block, finallyblockargs))
    end

    push!(ret, accept_end(ps))
    return setscope!(ret)
end

@addctx :do function parse_do(ps::ParseState, ret::EXPR)
    kw = mKEYWORD(next(ps))

    args = EXPR(TupleH, EXPR[])
    @closer ps comma @closer ps block while !closer(ps)
        a = parse_expression(ps)
        setbinding!(a)
        push!(args, a)
        if kindof(ps.nt) == Tokens.COMMA
            accept_comma(ps, args)
        end
    end

    blockargs = parse_block(ps)

    return setscope!(EXPR(Do, EXPR[ret, kw, args, EXPR(Block, blockargs), accept_end(ps)]))
end

# modules

@addctx :module function parse_module(ps::ParseState)
    sb = ps.t.startbyte
    kw = mKEYWORD(ps)
    @assert kindof(kw) == Tokens.MODULE || kindof(kw) == Tokens.BAREMODULE # work around julia issue #23766
    if kindof(ps.nt) == Tokens.IDENTIFIER
        arg = mIDENTIFIER(next(ps))
    else
        arg = @precedence ps 15 @closer ps ws parse_expression(ps)
    end
    sb1 = ps.nt.startbyte

    blockargs = parse_block(ps, EXPR[], (Tokens.END,), true)

    if isempty(blockargs)
        block = EXPR(Block, blockargs, 0, 0)
    else
        fullspan = ps.nt.startbyte - sb1
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
    end
    ender = accept_end(ps)
    fullspan1 = ps.nt.startbyte - sb
    return setscope!(EXPR(is_module(kw) ? ModuleH : BareModule, EXPR[kw, arg, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span), Scope(nothing, Dict{String,Binding}(), nothing, true))
end


function parse_mutable(ps::ParseState)
    if kindof(ps.nt) == Tokens.STRUCT
        kw = mKEYWORD(ps)
        next(ps)
        ret = parse_struct(ps, true)
        pushfirst!(ret, kw)
        update_span!(ret)
    else
        ret = mIDENTIFIER(ps)
    end
    return setscope!(ret)
end

function markparameters!(sig::EXPR)
    signame = rem_where_subtype(sig)
    if typof(signame) === Curly
        for i = 3:length(signame.args) - 1
            if !(typof(signame.args[i]) === PUNCTUATION)
                setbinding!(signame.args[i])
            end
        end
    end
    return sig
end

@addctx :struct function parse_struct(ps::ParseState, mutable::Bool)
    sb = ps.t.startbyte
    kw = mKEYWORD(ps)
    sig = @closer ps ws parse_expression(ps)    
    markparameters!(sig)

    sb1 = ps.nt.startbyte
    blockargs = parse_block(ps)
    for a in blockargs
        setbinding!(a)
    end
    if isempty(blockargs)
        block = EXPR(Block, blockargs, 0, 0)
    else
        fullspan = ps.nt.startbyte - sb1
        block = EXPR(Block, blockargs, fullspan, fullspan - last(blockargs).fullspan + last(blockargs).span)
    end
    ender = accept_end(ps)
    fullspan1 = ps.nt.startbyte - sb
    if mutable
        ret = EXPR(Mutable, EXPR[kw, sig, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span)
    else
        ret = setscope!(EXPR(Struct, EXPR[kw, sig, block, ender], fullspan1, fullspan1 - ender.fullspan + ender.span))
    end
    return ret
end
