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
    elseif ps.t.kind == Tokens.MODULE || ps.t.kind == Tokens.BAREMODULE
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, [kw.val=="module" ? TRUE : FALSE, arg, block], ps.ws.endbyte - start, [INSTANCE(ps)])
    elseif ps.t.kind == Tokens.TYPE || ps.t.kind == Tokens.IMMUTABLE
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, [kw.val=="type" ? TRUE : FALSE, arg, block], ps.ws.endbyte - start, [INSTANCE(ps)])
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
        return EXPR(kw, [arg, block], ps.ws.endbyte - start, [INSTANCE(ps)])
    else
        error(ps)
    end
end

function parse_if(ps::ParseState, nested = false)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    kw.val = "if"
    cond = @closer ps ws @closer ps block parse_expression(ps)

    if ps.nt.kind==Tokens.END
        next(ps)
        return EXPR(kw, [cond, EXPR(BLOCK, [], 0)], ps.ws.endbyte - start)
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

    !nested && next(ps)
    ret = isempty(elseblock.args) ? 
        EXPR(kw, [cond, ifblock], ps.ws.endbyte - start) : 
        EXPR(kw, [cond, ifblock, elseblock], ps.ws.endbyte - start)
    return ret
end


function parse_try(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    tryblock = EXPR(BLOCK, [], 0)
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
        catchblock = EXPR(BLOCK, [], 0)
    end
    next(ps)
    return EXPR(kw, [tryblock, caught ,catchblock], ps.ws.endbyte - start)
end

function parse_imports(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    M = INSTANCE[]
    if ps.nt.kind==Tokens.DDOT
        push!(M, INSTANCE{OPERATOR{15}}(".", "", 1))
        push!(M, INSTANCE{OPERATOR{15}}(".", "", 1))
        next(ps)
    end
    @assert ps.nt.kind == Tokens.IDENTIFIER "incomplete import statement"
    push!(M, INSTANCE(next(ps)))
    puncs = []
    while ps.nt.kind==Tokens.DOT
        push!(puncs, INSTANCE(next(ps)))
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(M, INSTANCE(next(ps)))
    end
    if closer(ps)
        ret =  EXPR(kw, M, ps.ws.endbyte - start, puncs)
    else
        @assert ps.nt.kind == Tokens.COLON
        push!(puncs, INSTANCE(next(ps)))
        args = parse_list(ps, puncs)
        if length(args)==1
            push!(M, first(args))
            ret = EXPR(kw, M, ps.ws.endbyte - start, puncs)
        else
            ret = EXPR(INSTANCE{KEYWORD}("toplevel", kw.ws, kw.span), [], ps.ws.endbyte - start, puncs)
            for a in args
                push!(ret.args, EXPR(kw, vcat(M, a), a.span))
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
    puncs = []
    while ps.nt.kind==Tokens.COMMA
        push!(puncs, INSTANCE(next(ps)))
        @assert ps.nt.kind == Tokens.IDENTIFIER "expected only symbols in import statement"
        push!(args, INSTANCE(next(ps)))
    end

    return EXPR(kw, args, ps.ws.endbyte - start, puncs)
end