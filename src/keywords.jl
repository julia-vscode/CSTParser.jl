
function parse_kw_syntax(ps::ParseState) 
    if Tokens.begin_0arg_kw < ps.t.kind < Tokens.end_0arg_kw
        kw = INSTANCE(ps)
        return EXPR(kw, [], LOCATION(kw.loc.start, kw.loc.stop))
    elseif Tokens.begin_1arg_kw < ps.t.kind < Tokens.end_1arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg = parse_expression(ps)
        return EXPR(kw, [arg], LOCATION(kw.loc.start, arg.loc.stop))
    elseif Tokens.begin_2arg_kw < ps.t.kind < Tokens.end_2arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg1 = @with_ws_delim ps parse_expression(ps) 
        arg2 = parse_expression(ps)
        return EXPR(kw, [arg1, arg2], LOCATION(kw.loc.start, arg2.loc.stop))
    elseif Tokens.begin_3arg_kw < ps.t.kind < Tokens.end_3arg_kw
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg = parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END || (!isempty(ps.ws.val) && !isoperator(ps.nt)))
        block = parse_block(ps)
        if kw.val=="type"
            return EXPR(kw, [TRUE, arg, block], LOCATION(kw.loc.start, block.loc.stop))
        elseif kw.val=="immutable"
            return EXPR(kw, [FALSE, arg, block], LOCATION(kw.loc.start, block.loc.stop))
        elseif kw.val=="module"
            return EXPR(kw, [TRUE, arg, block], LOCATION(kw.loc.start, block.loc.stop))
        elseif kw.val=="baremodule"
            return EXPR(kw, [FALSE, arg, block], LOCATION(kw.loc.start, block.loc.stop))
        else
            return EXPR(kw, [arg, block], LOCATION(kw.loc.start, block.loc.stop))
        end
    elseif ps.t.kind==Tokens.BEGIN || ps.t.kind==Tokens.QUOTE
        start = ps.t.startbyte
        kw = INSTANCE(ps)
        arg = parse_block(ps)
        return EXPR(kw, [arg], LOCATION(kw.loc.start, 0))
    elseif ps.t.kind==Tokens.IF
        parse_if(ps)
    elseif ps.t.kind==Tokens.TRY
        parse_try(ps)
    else
        error()
    end
end

function parse_if(ps::ParseState)
    kw = INSTANCE(ps)
    kw.val = "if"
    cond = parse_expression(ps)
    ifblock = EXPR(BLOCK, [], LOCATION(0, 0))
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.ELSE && ps.nt.kind!==Tokens.ELSEIF
        push!(ifblock.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END || ps.nt.kind==Tokens.ELSEIF || ps.nt.kind==Tokens.ELSE))
    end
    next(ps)
    if ps.t.kind==Tokens.END
        ret = EXPR(kw, [cond, ifblock], LOCATION(kw.loc.start, ps.t.endbyte))
    elseif ps.t.kind==Tokens.ELSEIF
        elseblock = parse_if(ps)
        ret = EXPR(kw, [cond, ifblock, elseblock], LOCATION(kw.loc.start, ps.t.endbyte))
    elseif ps.t.kind==Tokens.ELSE
        elseblock = parse_block(ps)
        ret = EXPR(kw, [cond, ifblock, elseblock], LOCATION(kw.loc.start, ps.t.endbyte))
    end
    return ret
end


function parse_try(ps::ParseState)
    kw = INSTANCE(ps)
    
    tryblock = EXPR(BLOCK, [], LOCATION(0, 0))
    while ps.nt.kind!==Tokens.END && ps.nt.kind!==Tokens.CATCH 
        push!(tryblock.args, parse_expression(ps,ps->closer_default(ps) || ps.nt.kind==Tokens.END || ps.nt.kind==Tokens.CATCH))
    end
    next(ps)
    if ps.t.kind==Tokens.CATCH
        caught = parse_expression(ps, ps-> closer_default(ps))
        catchblock = parse_block(ps)
        if !(caught isa INSTANCE)
            unshift!(catchblock.args, caught)
            caught = FALSE
        end
    else
        caught = FALSE
        catchblock = EXPR(BLOCK, [], LOCATION(0, 0))
    end
    return EXPR(kw, [tryblock, caught ,catchblock], LOCATION(kw.loc.start, ps.t.endbyte))
end