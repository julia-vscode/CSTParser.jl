function parse_kw_syntax(ps::ParseState)
    start = ps.t.startbyte
    if ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE   
        kw = INSTANCE(ps)
        arg = parse_block(ps)
        next(ps)
        return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1, [INSTANCE(ps)])
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
            return  EXPR(kw, Expression[NOTHING], ps.ws.endbyte - start + 1)
        else
            arg = parse_expression(ps)
            return  EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
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
        return EXPR(kw, Expression[kw isa INSTANCE{KEYWORD,Tokens.TYPE} ? TRUE : FALSE, arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
    elseif Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        kw = INSTANCE(ps)
        return EXPR(kw, Expression[], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        kw = INSTANCE(ps)
        arg = parse_expression(ps)
        return EXPR(kw, Expression[arg], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        kw = INSTANCE(ps)
        arg1 = @closer ps ws parse_expression(ps) 
        arg2 = parse_expression(ps)
        return EXPR(kw, Expression[arg1, arg2], ps.ws.endbyte - start + 1)
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        kw = INSTANCE(ps)
        arg = @closer ps block @closer ps ws parse_expression(ps)
        block = parse_block(ps)
        next(ps)
        return EXPR(kw, Expression[arg, block], ps.ws.endbyte - start + 1, INSTANCE[INSTANCE(ps)])
    else
        error(ps)
    end
end


