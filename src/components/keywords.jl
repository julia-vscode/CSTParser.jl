# Prefix 

function parse_const(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Const}(Any[kw, arg])
end

function parse_global(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Global}(Any[kw, arg])
end

function parse_local(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps arg = parse_expression(ps)

    return EXPR{Local}(Any[kw, arg])
end

function parse_return(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps args = closer(ps) ? NOTHING : parse_expression(ps)

    return EXPR{Return}(Any[kw, args])
end


# One line

function parse_abstract(ps::ParseState)
    # Switch for v0.6 compatability
    if ps.nt.kind == Tokens.TYPE
        kw1 = KEYWORD(ps)
        kw2 = KEYWORD(next(ps))
        @catcherror ps sig = @closer ps block parse_expression(ps)
        ret = EXPR{Abstract}(Any[kw1, kw2, sig, KEYWORD(next(ps))])
    else
        kw = KEYWORD(ps)
        @catcherror ps sig = parse_expression(ps)
        ret = EXPR{Abstract}(Any[kw, sig])
    end
    return ret
end

function parse_primitive(ps::ParseState)
    if ps.nt.kind == Tokens.TYPE
        kw1 = KEYWORD(ps)
        kw2 = KEYWORD(next(ps))
        @catcherror ps sig = @closer ps ws @closer ps wsop parse_expression(ps)
        @catcherror ps arg = @closer ps block parse_expression(ps)

        ret = EXPR{Primitive}(Any[kw1, kw2, sig, arg, KEYWORD(next(ps))])
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end

function parse_imports(ps::ParseState)
    kw = KEYWORD(ps)
    kwt = is_import(kw) ? Import :
          is_importall(kw) ? ImportAll :
          Using
    tk = ps.t.kind

    arg = parse_dot_mod(ps)

    if ps.nt.kind != Tokens.COMMA && ps.nt.kind != Tokens.COLON
        ret = EXPR{kwt}(vcat(kw, arg))
    elseif ps.nt.kind == Tokens.COLON
        ret = EXPR{kwt}(vcat(kw, arg))
        push!(ret, OPERATOR(next(ps)))

        @catcherror ps arg = parse_dot_mod(ps, true)
        append!(ret, arg)
        while ps.nt.kind == Tokens.COMMA
            push!(ret, PUNCTUATION(next(ps)))
            @catcherror ps arg = parse_dot_mod(ps, true)
            append!(ret, arg)
        end
    else
        ret = EXPR{kwt}(vcat(kw, arg))
        while ps.nt.kind == Tokens.COMMA
            push!(ret, PUNCTUATION(next(ps)))
            @catcherror ps arg = parse_dot_mod(ps)
            append!(ret, arg)
        end
    end

    return ret
end

function parse_export(ps::ParseState)
    args = Any[KEYWORD(ps)]
    append!(args, parse_dot_mod(ps))

    while ps.nt.kind == Tokens.COMMA
        push!(args, PUNCTUATION(next(ps)))
        @catcherror ps arg = parse_dot_mod(ps)[1]
        push!(args, arg)
    end

    return EXPR{Export}(args)
end


# Block

function parse_begin(ps::ParseState)
    kw = KEYWORD(ps)
    blockargs = Any[]
    @catcherror ps arg = parse_block(ps, blockargs, (Tokens.END,), true)

    return EXPR{Begin}(Any[kw, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end

function parse_quote(ps::ParseState)
    kw = KEYWORD(ps)
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    return EXPR{Quote}(Any[kw, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end

function parse_function(ps::ParseState)
    kw = KEYWORD(ps)
    
    @catcherror ps sig = @closer ps inwhere @closer ps ws parse_expression(ps)

    if sig isa EXPR{InvisBrackets} && !(sig.args[2] isa EXPR{TupleH})
        istuple = true
        sig = EXPR{TupleH}(sig.args)
    elseif sig isa EXPR{TupleH}
        istuple = true
    else
        istuple = false
    end

    while ps.nt.kind == Tokens.WHERE && ps.ws.kind != Tokens.NEWLINE_WS
        @catcherror ps sig = @closer ps inwhere @closer ps ws parse_compound(ps, sig)
    end
    
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    if isempty(blockargs)
        if sig isa EXPR{Call} || sig isa WhereOpCall || (sig isa BinarySyntaxOpCall && !(is_exor(sig.arg1))) || istuple
            args = Any[sig, EXPR{Block}(blockargs)]
        else
            args = Any[sig]
        end
    else
        args = Any[sig, EXPR{Block}(blockargs)]
    end

    ret = EXPR{FunctionDef}(Any[kw])
    for a in args
        push!(ret, a)
    end
    push!(ret, KEYWORD(next(ps)))
    return ret
end

function parse_macro(ps::ParseState)
    kw = KEYWORD(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        sig = IDENTIFIER(next(ps))
        @catcherror ps sig = parse_call(ps, sig)
    else
        @catcherror ps sig = @closer ps ws parse_expression(ps)
    end

    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    return EXPR{Macro}(Any[kw, sig, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end

# loops
function parse_for(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps ranges = parse_ranges(ps)

    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)
    return EXPR{For}(Any[kw, ranges, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end

function parse_while(ps::ParseState)
    kw = KEYWORD(ps)
    @catcherror ps cond = @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    return EXPR{While}(Any[kw, cond, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end

# control flow

"""
    parse_if(ps, ret, nested=false, puncs=[])

Parse an `if` block.
"""
function parse_if(ps::ParseState, nested = false)
    # Parsing
    kw = KEYWORD(ps)
    if ps.ws.kind == NewLineWS || ps.ws.kind == SemiColonWS
        return make_error(ps, 1 .+ (ps.t.endbyte:ps.t.endbyte), Diagnostics.MissingConditional,
            "missing conditional in `$(lowercase(string(ps.t.kind)))`")
    end
    @catcherror ps cond = @closer ps ws parse_expression(ps)


    ifblockargs = Any[]
    @catcherror ps @closer ps ifelse parse_block(ps, ifblockargs, (Tokens.END, Tokens.ELSE, Tokens.ELSEIF))

    if nested
        ret = EXPR{If}(Any[cond, EXPR{Block}(ifblockargs)])
    else
        ret = EXPR{If}(Any[kw, cond, EXPR{Block}(ifblockargs)])
    end

    elseblock = EXPR{Block}(Any[], 0, 1:0)
    if ps.nt.kind == Tokens.ELSEIF
        push!(ret, KEYWORD(next(ps)))

        @catcherror ps push!(elseblock, parse_if(ps, true))
    end
    elsekw = ps.nt.kind == Tokens.ELSE
    if ps.nt.kind == Tokens.ELSE
        push!(ret, KEYWORD(next(ps)))
        @catcherror ps parse_block(ps, elseblock)
    end

    # Construction
    !nested && next(ps)
    if !(isempty(elseblock.args) && !elsekw)
        push!(ret, elseblock)
    end
    !nested && push!(ret, KEYWORD(ps))

    return ret
end

function parse_let(ps::ParseState)
    args = Any[KEYWORD(ps)]
    if !(ps.ws.kind == NewLineWS || ps.ws.kind == SemiColonWS)
        arg = @closer ps range @closer ps ws @closer ps newline parse_expression(ps)
        if ps.nt.kind == Tokens.COMMA
            arg = EXPR{Block}(Any[arg])
            while ps.nt.kind == Tokens.COMMA
                push!(arg, PUNCTUATION(next(ps)))

                startbyte = ps.nt.startbyte
                @catcherror ps nextarg = @closer ps comma @closer ps ws parse_expression(ps)
                push!(arg, nextarg)
            end
        end
        push!(args, arg)
    end
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    push!(args, EXPR{Block}(blockargs))
    push!(args, KEYWORD(next(ps)))

    return EXPR{Let}(args)
end

function parse_try(ps::ParseState)
    kw = KEYWORD(ps)
    ret = EXPR{Try}(Any[kw])

    tryblockargs = Any[]
    @catcherror ps @closer ps trycatch parse_block(ps, tryblockargs, (Tokens.END, Tokens.CATCH, Tokens.FINALLY))
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
                @catcherror ps caught = @closer ps ws @closer ps trycatch parse_expression(ps)
            end
            catchblock = EXPR{Block}(Any[], 0, 1:0)
            @catcherror ps @closer ps trycatch parse_block(ps, catchblock, (Tokens.END, Tokens.FINALLY))
            if !(caught isa IDENTIFIER || caught == FALSE)
                pushfirst!(catchblock, caught)
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

function parse_do(ps::ParseState, @nospecialize(ret))
    kw = KEYWORD(next(ps))

    args = EXPR{TupleH}(Any[])
    @closer ps comma @closer ps block while !closer(ps)
        @catcherror ps a = parse_expression(ps)

        push!(args, a)
        if ps.nt.kind == Tokens.COMMA
            push!(args, PUNCTUATION(next(ps)))
        end
    end

    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)

    return EXPR{Do}(Any[ret, kw, args, EXPR{Block}(blockargs), PUNCTUATION(next(ps))])
end

# modules

function parse_module(ps::ParseState)
    kw = KEYWORD(ps)
    @assert kw.kind == Tokens.MODULE || kw.kind == Tokens.BAREMODULE # work around julia issue #23766
    if ps.nt.kind == Tokens.IDENTIFIER
        arg = IDENTIFIER(next(ps))
    else
        @catcherror ps arg = @precedence ps 15 @closer ps ws parse_expression(ps)
    end

    block = EXPR{Block}(Any[])
    parse_block(ps, block, (Tokens.END,), true)

    return EXPR{(is_module(kw) ? ModuleH : BareModule)}(Any[kw, arg, block, KEYWORD(next(ps))])
end


function parse_mutable(ps::ParseState)
    if ps.nt.kind == Tokens.STRUCT
        kw = KEYWORD(ps)
        next(ps)
        @catcherror ps ret = parse_struct(ps, true)
        pushfirst!(ret, kw)
        update_span!(ret)
    else
        ret = IDENTIFIER(ps)
    end
    return ret
end


function parse_struct(ps::ParseState, mutable)
    kw = KEYWORD(ps)
    @catcherror ps sig = @closer ps ws parse_expression(ps)
    blockargs = Any[]
    @catcherror ps parse_block(ps, blockargs)
    
    return EXPR{mutable ? Mutable : Struct}(Any[kw, sig, EXPR{Block}(blockargs), KEYWORD(next(ps))])
end
