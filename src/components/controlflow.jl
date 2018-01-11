function parse_do(ps::ParseState, ret::ANY)
    kw = KEYWORD(next(ps))

    args = EXPR{TupleH}(Any[])
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)

        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            push!(args, PUNCTUATION(next(ps)))
        end
    end

    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    return EXPR{Do}(Any[ret, kw, args, EXPR{Block}(blockargs), PUNCTUATION(next(ps))])
end

"""
    parse_if(ps)

Parse an `if` block.
"""
function parse_if(ps::ParseState)
    ifargs = Any[]
    found_else = false
    while true
        kw = KEYWORD(ps)
        push!(ifargs, kw)
        ps.t.kind == Tokens.END && break
        if found_else
            return make_error(ps, 1 + (ps.t.startbyte:ps.t.endbyte), Diagnostics.UnexpectedToken,
                              "expected `end` got `$(val(ps.t, ps))`")
        end
        if ps.t.kind != Tokens.ELSE
            if ps.ws.kind == NewLineWS || ps.ws.kind == SemiColonWS
                return make_error(ps, 1 + (ps.t.endbyte:ps.t.endbyte), Diagnostics.MissingConditional,
                    "missing conditional in `$(lowercase(string(ps.t.kind)))`")
            end
            @catcherror ps cond = @default ps @closer ps block @closer ps ws parse_expression(ps)
            push!(ifargs, cond)
        else
            found_else = true
        end
        block = Any[]
        @catcherror ps @default ps @closer ps ifelse parse_block(ps, block, (Tokens.END, Tokens.ELSE, Tokens.ELSEIF))
        push!(ifargs, EXPR{Block}(block))
        next(ps)
    end
    return EXPR{If}(ifargs)
end

function parse_let(ps::ParseState)
    args = Any[KEYWORD(ps)]
    @default ps @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)
        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            push!(args, PUNCTUATION(next(ps)))
        end
    end

    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)

    push!(args, EXPR{Block}(blockargs))
    push!(args, KEYWORD(next(ps)))

    return EXPR{Let}(args)
end

function parse_try(ps::ParseState)
    kw = KEYWORD(ps)
    ret = EXPR{Try}(Any[kw])

    tryblockargs = Any[]
    @catcherror ps @default ps @closer ps trycatch parse_block(ps, tryblockargs, (Tokens.END, Tokens.CATCH, Tokens.FINALLY))
    push!(ret, EXPR{Block}(tryblockargs))

    # try closing early
    if ps.nt.kind == Tokens.END
        push!(ret, FALSE)
        push!(ret, EXPR{Block}(Any[], 0, 1:0))
        push!(ret, KEYWORD(next(ps)))
        return ret
    end

    #  catch block
    if ps.nt.kind == Tokens.CATCH
        next(ps)
        # catch closing early
        if ps.nt.kind == Tokens.FINALLY || ps.nt.kind == Tokens.END
            push!(ret, KEYWORD(ps))
            caught = FALSE
            catchblock = EXPR{Block}(Any[], 0, 1:0)
        else
            start_col = ps.t.startpos[2] + 4
            push!(ret, KEYWORD(ps))
            if ps.ws.kind == SemiColonWS || ps.ws.kind == NewLineWS
                caught = FALSE
            else
                @catcherror ps caught = @default ps @closer ps ws @closer ps trycatch parse_expression(ps)
            end
            catchblock = EXPR{Block}(Any[], 0, 1:0)
            @catcherror ps @default ps @closer ps trycatch parse_block(ps, catchblock, (Tokens.END, Tokens.FINALLY))
            if !(caught isa IDENTIFIER || caught == FALSE)
                unshift!(catchblock, caught)
                caught = FALSE
            end
        end
    else
        caught = FALSE
        catchblock = EXPR{Block}(Any[], 0, 1:0)
    end
    push!(ret, caught)
    push!(ret, catchblock)

    # finally block
    if ps.nt.kind == Tokens.FINALLY
        if isempty(catchblock.args)
            ret.args[4] = FALSE
        end
        push!(ret, KEYWORD(next(ps)))
        finallyblock = EXPR{Block}(Any[], 0, 1:0)
        @catcherror ps parse_block(ps, finallyblock)
        push!(ret, finallyblock)
    end

    push!(ret, KEYWORD(next(ps)))
    return ret
end
