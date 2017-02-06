function parse_kw_syntax(ps::ParseState)
    start = ps.t.startbyte
    if ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE   
        kw = INSTANCE(ps)
        arg = parse_block(ps)
        next(ps)
        return EXPR(kw, [arg], ps.ws.endbyte - start)
    elseif ps.t.kind==Tokens.IF
        return parse_if(ps)
    elseif ps.t.kind==Tokens.TRY
        parse_try(ps)
    elseif ps.t.kind==Tokens.IMPORT || ps.t.kind==Tokens.IMPORTALL || ps.t.kind==Tokens.USING
        return parse_imports(ps)
    elseif ps.t.kind==Tokens.EXPORT
        return parse_export(ps)
    elseif ps.t.kind==Tokens.RETURN
        kw = INSTANCE(ps)
        if closer(ps)
            return  EXPR(kw, [NOTHING], ps.ws.endbyte - start)
        else
            arg = parse_expression(ps)
            return  EXPR(kw, [arg], ps.ws.endbyte - start)
        end
    elseif Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        kw = INSTANCE(ps)
        return EXPR(kw, [], ps.ws.endbyte - start)
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        kw = INSTANCE(ps)
        arg = parse_expression(ps)
        return EXPR(kw, [arg], ps.ws.endbyte - start)
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        kw = INSTANCE(ps)
        arg1 = @closer ps ws parse_expression(ps) 
        arg2 = parse_expression(ps)
        return EXPR(kw, [arg1, arg2], ps.ws.endbyte - start)
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        if kw.val=="type"
            return EXPR(kw, [TRUE, arg, block], ps.ws.endbyte - start)
        elseif kw.val=="immutable"
            return EXPR(kw, [FALSE, arg, block], ps.ws.endbyte - start)
        elseif kw.val=="module"
            return EXPR(kw, [TRUE, arg, block], ps.ws.endbyte - start)
        elseif kw.val=="baremodule"
            return EXPR(kw, [FALSE, arg, block], ps.ws.endbyte - start)
        else
            return EXPR(kw, [arg, block], ps.ws.endbyte - start)
        end
    else
        error(ps)
    end
end

function parse_if(ps::ParseState, nested = false)
    kw = INSTANCE(ps)
    kw.val = "if"
    cond = @closer ps ws @closer ps block parse_expression(ps)
    if ps.nt.kind==Tokens.END
        next(ps)
        return EXPR(kw, [cond, EXPR(BLOCK, [], LOCATION(0, 0))], kw.span + cond.span +  ps.ws.endbyte - ps.t.startbyte)
    end
    ifblock = EXPR(BLOCK, [], -ps.t.startbyte)
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.ELSE && ps.nt.kind!==Tokens.ELSEIF
        push!(ifblock.args, @closer ps ifelse parse_expression(ps))
    end
    ifblock.span +=ps.ws.endbyte

    elseblock = EXPR(BLOCK, [], -ps.nt.startbyte)
    if ps.nt.kind==Tokens.ELSEIF
        next(ps)
        push!(elseblock.args, parse_if(ps, true))
    end
    if ps.nt.kind==Tokens.ELSE
        next(ps)
        parse_block(ps, elseblock)
    end
    elseblock.span += ps.nt.endbyte

    ret = isempty(elseblock.args) ? 
        EXPR(kw, [cond, ifblock], kw.span + cond.span + ifblock.span + ps.ws.endbyte - ps.t.startbyte) : 
        EXPR(kw, [cond, ifblock, elseblock], kw.span + cond.span + ifblock.span + elseblock.span + ps.ws.endbyte - ps.t.startbyte)
    !nested && next(ps)
    return ret
end


function parse_try(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    tryblock = EXPR(BLOCK, [], LOCATION(0, 0))
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.CATCH 
        push!(tryblock.args, @closer ps trycatch parse_expression(ps))
    end
    next(ps)
    if ps.t.kind==Tokens.CATCH
        caught = parse_expression(ps)
        catchblock = parse_block(ps)
        if !(caught isa INSTANCE)
            unshift!(catchblock.args, caught)
            caught = FALSE
        end
    else
        caught = FALSE
        catchblock = EXPR(BLOCK, [], LOCATION(0, 0))
    end
    next(ps)
    return EXPR(kw, [tryblock, caught ,catchblock], ps.ws.endbyte - start)
end

function parse_imports(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    @assert ps.nt.kind == Tokens.IDENTIFIER "incomplete import statement"
    M = INSTANCE[INSTANCE(next(ps))]
    while ps.nt.kind==Tokens.DOT
        next(ps)
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(M, INSTANCE(next(ps)))
    end
    if closer(ps)
        ret =  EXPR(kw, M, ps.ws.endbyte - start)
    else
        @assert ps.nt.kind == Tokens.COLON
        next(ps)
        args = parse_list(ps)
        if length(args)==1
            push!(M, first(args))
            ret = EXPR(kw, M, ps.ws.endbyte - start)
        else
            ret = EXPR(INSTANCE{KEYWORD}("toplevel", kw.ws, kw.loc), [], ps.ws.endbyte - start)
            for a in args
                push!(ret.args, EXPR(kw, vcat(M, a), a.loc))
            end
        end
    end
    return ret
end

function parse_export(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    @assert ps.nt.kind == Tokens.IDENTIFIER "incomplete export statement"
    args = INSTANCE[INSTANCE(next(ps))]
    while ps.nt.kind==Tokens.COMMA
        next(ps)
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(args, INSTANCE(next(ps)))
    end

    return EXPR(kw, args, ps.ws.endbyte - start)
end