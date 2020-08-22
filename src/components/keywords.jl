"""
    parse_kw(ps::ParseState)

Dispatch function for when the parser has reached a keyword.
"""
function parse_kw(ps::ParseState)
    k = kindof(ps.t)
    if k === Tokens.IF
        return @default ps @closer ps :block parse_if(ps)
    elseif k === Tokens.LET
        return @default ps @closer ps :block parse_blockexpr(ps, Let)
    elseif k === Tokens.TRY
        return @default ps @closer ps :block parse_try(ps)
    elseif k === Tokens.FUNCTION
        return @default ps @closer ps :block parse_blockexpr(ps, FunctionDef)
    elseif k === Tokens.MACRO
        return @default ps @closer ps :block parse_blockexpr(ps, Macro)
    elseif k === Tokens.BEGIN
        @static if VERSION < v"1.4"
            return @default ps @closer ps :block parse_blockexpr(ps, Begin)
        else
            if ps.closer.inref
                ret = mKEYWORD(ps)
            else
                return @default ps @closer ps :block parse_blockexpr(ps, Begin)
            end
        end
    elseif k === Tokens.QUOTE
        return @default ps @closer ps :block parse_blockexpr(ps, Quote)
    elseif k === Tokens.FOR
        return @default ps @closer ps :block parse_blockexpr(ps, For)
    elseif k === Tokens.WHILE
        return @default ps @closer ps :block parse_blockexpr(ps, While)
    elseif k === Tokens.BREAK
        return INSTANCE(ps)
    elseif k === Tokens.CONTINUE
        return INSTANCE(ps)
    elseif k === Tokens.IMPORT
        return parse_imports(ps)
    elseif k === Tokens.USING
        return parse_imports(ps)
    elseif k === Tokens.EXPORT
        return parse_export(ps)
    elseif k === Tokens.MODULE
        return @default ps @closer ps :block parse_blockexpr(ps, ModuleH)
    elseif k === Tokens.BAREMODULE
        return @default ps @closer ps :block parse_blockexpr(ps, BareModule)
    elseif k === Tokens.CONST
        return @default ps parse_const(ps)
    elseif k === Tokens.GLOBAL
        return @default ps parse_global(ps)
    elseif k === Tokens.LOCAL
        return @default ps parse_local(ps)
    elseif k === Tokens.RETURN
        return @default ps parse_return(ps)
    elseif k === Tokens.END
        if ps.closer.square
            ret = mKEYWORD(ps)
        else
            ret = mErrorToken(ps, mIDENTIFIER(ps), UnexpectedToken)
        end
        return ret
    elseif k === Tokens.ELSE || k === Tokens.ELSEIF || k === Tokens.CATCH || k === Tokens.FINALLY
        return mErrorToken(ps, mIDENTIFIER(ps), UnexpectedToken)
    elseif k === Tokens.ABSTRACT
        return @default ps parse_abstract(ps)
    elseif k === Tokens.PRIMITIVE
        return @default ps parse_primitive(ps)
    elseif k === Tokens.TYPE
        return mIDENTIFIER(ps)
    elseif k === Tokens.STRUCT
        return @default ps @closer ps :block parse_blockexpr(ps, Struct)
    elseif k === Tokens.MUTABLE
        return @default ps @closer ps :block parse_mutable(ps)
    elseif k === Tokens.OUTER
        return mIDENTIFIER(ps)
    else
        return mErrorToken(ps, Unknown)
    end
end

function parse_const(ps::ParseState)
    kw = mKEYWORD(ps)
    arg = parse_expression(ps)
    if !(is_assignment(unwrapbracket(arg)) || (typof(arg) === Global && is_assignment(unwrapbracket(arg.args[2]))))
        arg = mErrorToken(ps, arg, ExpectedAssignment)
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
    # Note to self: Nothing could be treated as implicit and added
    # during conversion to Expr.
    args = closer(ps) ? NOTHING() : parse_expression(ps)

    return EXPR(Return, EXPR[kw, args])
end

function parse_abstract(ps::ParseState)
    if kindof(ps.nt) === Tokens.TYPE
        kw1 = mKEYWORD(ps)
        kw2 = mKEYWORD(next(ps))
        sig = @closer ps :block parse_expression(ps)
        ret = EXPR(Abstract, EXPR[kw1, kw2, sig, accept_end(ps)])
    else
        ret = mIDENTIFIER(ps)
    end
    return ret
end

function parse_primitive(ps::ParseState)
    if kindof(ps.nt) === Tokens.TYPE
        kw1 = mKEYWORD(ps)
        kw2 = mKEYWORD(next(ps))
        sig = @closer ps :ws @closer ps :wsop parse_expression(ps)
        arg = @closer ps :block parse_expression(ps)
        ret = EXPR(Primitive, EXPR[kw1, kw2, sig, arg, accept_end(ps)])
    else
        ret = mIDENTIFIER(ps)
    end
    return ret
end

function parse_mutable(ps::ParseState)
    if kindof(ps.nt) === Tokens.STRUCT
        kw = mKEYWORD(ps)
        next(ps)
        ret = parse_blockexpr(ps, Mutable)
        pushfirst!(ret, kw)
        update_span!(ret)
    else
        ret = mIDENTIFIER(ps)
    end
    return ret
end

function parse_imports(ps::ParseState)
    kw = mKEYWORD(ps)
    kwt = is_import(kw) ? Import : Using

    arg = parse_dot_mod(ps)

    if !iscomma(ps.nt) && !iscolon(ps.nt)
        ret = EXPR(kwt, vcat(kw, arg))
    elseif iscolon(ps.nt)
        ret = EXPR(kwt, vcat(kw, arg))
        push!(ret, mOPERATOR(next(ps)))

        arg = parse_dot_mod(ps, true)
        append!(ret, arg)
        safetytrip = 0
        while iscomma(ps.nt)
            safetytrip += 1
            if safetytrip > 10_000
                throw(CSTInfiniteLoop("Infinite loop at $ps"))
            end
            accept_comma(ps, ret)
            arg = parse_dot_mod(ps, true)
            append!(ret, arg)
        end
    else
        ret = EXPR(kwt, vcat(kw, arg))
        safetytrip = 0
        while iscomma(ps.nt)
            safetytrip += 1
            if safetytrip > 10_000
                throw(CSTInfiniteLoop("Infinite loop at $ps"))
            end
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

    safetytrip = 0
    while iscomma(ps.nt)
        safetytrip += 1
        if safetytrip > 10_000
            throw(CSTInfiniteLoop("Infinite loop at $ps"))
        end
        push!(args, mPUNCTUATION(next(ps)))
        arg = parse_dot_mod(ps)[1]
        push!(args, arg)
    end

    return EXPR(Export, args)
end

"""
    parse_blockexpr_sig(ps::ParseState, head)

Utility function to parse the signature of a block statement (i.e. any statement preceding
the main body of the block). Returns `nothing` in some cases (e.g. `begin end`)
"""
function parse_blockexpr_sig(ps::ParseState, head)
    if head === Struct || head == Mutable || head === While
        return @closer ps :ws parse_expression(ps)
    elseif head === For
        return parse_iterators(ps)
    elseif head === FunctionDef || head === Macro
        sig = @closer ps :inwhere @closer ps :ws parse_expression(ps)
        if convertsigtotuple(sig)
            sig = EXPR(TupleH, sig.args)
        end
        safetytrip = 0
        while kindof(ps.nt) === Tokens.WHERE && kindof(ps.ws) != Tokens.NEWLINE_WS
            safetytrip += 1
            if safetytrip > 10_000
                throw(CSTInfiniteLoop("Infinite loop at $ps"))
            end
            sig = @closer ps :inwhere @closer ps :ws parse_operator_where(ps, sig, INSTANCE(next(ps)), false)
        end
        return sig
    elseif head === Let
        if isendoflinews(ps.ws)
            return nothing
        else
            arg = @closer ps :comma @closer ps :ws  parse_expression(ps)
            if iscomma(ps.nt) || !(is_wrapped_assignment(arg) || isidentifier(arg))
                arg = EXPR(Block, EXPR[arg])
                safetytrip = 0
                while iscomma(ps.nt)
                    safetytrip += 1
                    if safetytrip > 10_000
                        throw(CSTInfiniteLoop("Infinite loop at $ps"))
                    end
                    accept_comma(ps, arg)
                    startbyte = ps.nt.startbyte
                    nextarg = @closer ps :comma @closer ps :ws parse_expression(ps)
                    push!(arg, nextarg)
                end
            end
            return arg
        end
    elseif head === Do
        sig = EXPR(TupleH, EXPR[])
        safetytrip = 0
        @closer ps :comma @closer ps :block while !closer(ps)
            safetytrip += 1
            if safetytrip > 10_000
                throw(CSTInfiniteLoop("Infinite loop at $ps"))
            end
            @closer ps :ws a = parse_expression(ps)
            push!(sig, a)
            if kindof(ps.nt) === Tokens.COMMA
                accept_comma(ps, sig)
            elseif @closer ps :ws closer(ps)
                break
            end
        end
        return sig
    elseif head === ModuleH || head === BareModule
        return isidentifier(ps.nt) ? mIDENTIFIER(next(ps)) :
            @precedence ps 15 @closer ps :ws parse_expression(ps)
    end
    return nothing
end

function parse_do(ps::ParseState, pre::EXPR)
    ret = parse_blockexpr(next(ps), Do)
    pushfirst!(ret, pre)
    update_span!(ret)
    return ret
end

"""
    parse_blockexpr(ps::ParseState, head)

General function for parsing block expressions comprised of a series of statements 
terminated by an `end`.
"""
function parse_blockexpr(ps::ParseState, head)
    kw = mKEYWORD(ps)
    sig = parse_blockexpr_sig(ps, head)
    blockargs = parse_block(ps, EXPR[], (Tokens.END,), docable(head))

    if sig === nothing
        EXPR(head, EXPR[kw, EXPR(Block, blockargs), accept_end(ps)])
    elseif (head === FunctionDef || head === Macro) && is_either_id_op_interp(sig)
        EXPR(head, EXPR[kw, sig, accept_end(ps)])
    else
        EXPR(head, EXPR[kw, sig, EXPR(Block, blockargs), accept_end(ps)])
    end
end


"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested=false)
    # Parsing
    kw = mKEYWORD(ps)
    if isendoflinews(ps.ws)
        cond = mErrorToken(ps, MissingConditional)
    else
        cond = @closer ps :ws parse_expression(ps)
    end
    ifblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.ELSE, Tokens.ELSEIF))

    if nested
        ret = EXPR(If, EXPR[cond, EXPR(Block, ifblockargs)])
    else
        ret = EXPR(If, EXPR[kw, cond, EXPR(Block, ifblockargs)])
    end

    elseblockargs = EXPR[]
    if kindof(ps.nt) === Tokens.ELSEIF
        push!(ret, mKEYWORD(next(ps)))
        push!(elseblockargs, parse_if(ps, true))
    end
    elsekw = kindof(ps.nt) === Tokens.ELSE
    if kindof(ps.nt) === Tokens.ELSE
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


function parse_try(ps::ParseState)
    kw = mKEYWORD(ps)
    ret = EXPR(Try, EXPR[kw])

    tryblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.CATCH, Tokens.FINALLY))
    push!(ret, EXPR(Block, tryblockargs))

    #  catch block
    if kindof(ps.nt) === Tokens.CATCH
        next(ps)
        push!(ret, mKEYWORD(ps))
        # catch closing early
        if kindof(ps.nt) === Tokens.FINALLY || kindof(ps.nt) === Tokens.END
            caught = FALSE()
            catchblock = EXPR(Block, EXPR[])
        else
            if isendoflinews(ps.ws)
                caught = FALSE()
            else
                caught = @closer ps :ws parse_expression(ps)
            end

            catchblockargs = parse_block(ps, EXPR[], (Tokens.END, Tokens.FINALLY))
            if !(is_either_id_op_interp(caught) || kindof(caught) === Tokens.FALSE)
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
    if kindof(ps.nt) === Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[4] = setparent!(FALSE(), ret)
        end
        push!(ret, mKEYWORD(next(ps)))
        finallyblockargs = parse_block(ps)
        push!(ret, EXPR(Block, finallyblockargs))
    end

    push!(ret, accept_end(ps))
    return ret
end
