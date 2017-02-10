function parse_kw_syntax(ps::ParseState)
    start = ps.t.startbyte
    if ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE   
        kw = INSTANCE(ps)
        arg = parse_block(ps)
        next(ps)
        return EXPR(kw, [arg], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
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
            return  EXPR(kw, [NOTHING], ps.ws.endbyte - start + 1)
        else
            arg = parse_expression(ps)
            return  EXPR(kw, [arg], ps.ws.endbyte - start + 1)
        end
    elseif ps.t.kind == Tokens.MODULE || ps.t.kind == Tokens.BAREMODULE
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, [kw isa INSTANCE{KEYWORD,Tokens.MODULE} ? TRUE : FALSE, arg, block], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
    elseif ps.t.kind == Tokens.TYPE || ps.t.kind == Tokens.IMMUTABLE
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, [kw isa INSTANCE{KEYWORD,Tokens.TYPE} ? TRUE : FALSE, arg, block], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
    elseif Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        kw = INSTANCE(ps)
        return EXPR(kw, [], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        kw = INSTANCE(ps)
        arg = parse_expression(ps)
        return EXPR(kw, [arg], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        kw = INSTANCE(ps)
        arg1 = @closer ps ws parse_expression(ps) 
        arg2 = parse_expression(ps)
        return EXPR(kw, [arg1, arg2], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, [arg, block], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
    else
        error(ps)
    end
end

function parse_if(ps::ParseState, nested = false, puncs = [])
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    cond = @closer ps ws @closer ps block parse_expression(ps)

    if ps.nt.kind==Tokens.END
        next(ps)
        return EXPR(kw, [cond, EXPR(BLOCK, [], 0)], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
    end

    ifblock = EXPR(BLOCK, [], -ps.nt.startbyte)
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.ELSE && ps.nt.kind!==Tokens.ELSEIF
        push!(ifblock.args, @closer ps ifelse parse_expression(ps))
    end
    ifblock.span +=ps.ws.endbyte + 1

    elseblock = EXPR(BLOCK, [], 0)
    if ps.nt.kind==Tokens.ELSEIF
        next(ps)
        push!(puncs, INSTANCE(ps))
        startelseblock = ps.ws.endbyte + 1
        push!(elseblock.args, parse_if(ps, true, puncs))
        elseblock.span = ps.ws.endbyte - startelseblock + 1
    end
    if ps.nt.kind==Tokens.ELSE
        next(ps)
        push!(puncs, INSTANCE(ps))
        startelseblock = ps.ws.endbyte + 1
        parse_block(ps, elseblock)
        elseblock.span = ps.ws.endbyte - startelseblock + 1
    end

    !nested && next(ps)
    !nested && push!(puncs, INSTANCE(ps))
    ret = isempty(elseblock.args) ? 
        EXPR(kw, [cond, ifblock], ps.ws.endbyte - start + 1, puncs) : 
        EXPR(kw, [cond, ifblock, elseblock], ps.ws.endbyte - start + 1, puncs)
    return ret
end


function parse_try(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    tryblock = EXPR(BLOCK, [], -ps.ws.endbyte)
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.CATCH 
        push!(tryblock.args, @closer ps trycatch parse_expression(ps))
    end
    tryblock.span += ps.ws.endbyte 

    puncs = INSTANCE[]
    next(ps)
    if ps.t.kind==Tokens.CATCH
        push!(puncs, INSTANCE(ps))
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
    ps.t.kind != Tokens.END && next(ps)
    push!(puncs, INSTANCE(ps))
    return EXPR(kw, [tryblock, caught ,catchblock], ps.ws.endbyte - start + 1, puncs)
end

function parse_imports(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    M = INSTANCE[]
    if ps.nt.kind==Tokens.DDOT
        push!(M, INSTANCE{OPERATOR{15},Tokens.DOT}(".", "", 1))
        push!(M, INSTANCE{OPERATOR{15},Tokens.DOT}(".", "", 1))
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
        ret =  EXPR(kw, M, ps.ws.endbyte - start + 1, puncs)
    else
        @assert ps.nt.kind == Tokens.COLON
        push!(puncs, INSTANCE(next(ps)))
        # args = parse_list(ps, puncs)
        args = Vector{INSTANCE}[]
        while ps.nt.kind == Tokens.IDENTIFIER
            a = INSTANCE[INSTANCE(next(ps))]
            while ps.nt.kind == Tokens.DOT
                push!(puncs, INSTANCE(next(ps)))
                push!(a, INSTANCE(next(ps)))
            end
            if ps.nt.kind == Tokens.COMMA || closer(ps)
                push!(args, a)
                !closer(ps) && push!(puncs, INSTANCE(next(ps)))
            else
                break
            end
        end
        if length(args)==1
            push!(M, first(args)...)
            ret = EXPR(kw, M, ps.ws.endbyte - start + 1, puncs)
        else
            ret = EXPR(INSTANCE{HEAD,Tokens.KEYWORD}("toplevel", kw.ws, kw.span), [], ps.ws.endbyte - start + 1, puncs)
            for a in args
                push!(ret.args, EXPR(kw, vcat(M, a), sum(y.span for y in a) + length(a) - 1))
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

    return EXPR(kw, args, ps.ws.endbyte - start + 1, puncs)
end