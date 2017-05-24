parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORT}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORTALL}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.USING}}) = parse_imports(ps)

parse_kw(ps::ParseState, ::Type{Val{Tokens.MODULE}}) = parse_module(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.BAREMODULE}}) = parse_module(ps)

function parse_module(ps::ParseState)
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
    else
        @catcherror ps startbyte arg = @precedence ps 15 @closer ps block @closer ps ws parse_expression(ps)
    end

    block = EXPR{Block}(EXPR[], -ps.nt.startbyte, Variable[], "")
    @scope ps Scope{Tokens.MODULE} @default ps while ps.nt.kind !== Tokens.END
        @catcherror ps startbyte a = @closer ps block parse_doc(ps)
        push!(block.args, a)
    end

    # Construction
    block.span += ps.nt.startbyte
    next(ps)
    ret = EXPR{(kw isa EXPR{KEYWORD{Tokens.MODULE}} ? ModuleH : BareModule)}(EXPR[kw, arg, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
    ret.defs = [Variable(Expr(arg), :module, ret)]
    return ret
end

function parse_dot_mod(ps::ParseState, colon = false)
    startbyte = ps.nt.startbyte
    args = EXPR[]

    while ps.nt.kind == Tokens.DOT || ps.nt.kind == Tokens.DDOT || ps.nt.kind == Tokens.DDDOT
        next(ps)
        d = INSTANCE(ps)
        if d isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
        elseif d isa EXPR{OPERATOR{ColonOp,Tokens.DDOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
        elseif d isa EXPR{OPERATOR{DddotOp,Tokens.DDDOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, Variable[], ""))
        end
    end

    # import/export ..
    if ps.nt.kind == Tokens.COMMA || ps.ws.kind == NewLineWS || ps.nt.kind == Tokens.ENDMARKER
        if length(args) == 2
            return EXPR[INSTANCE(ps)]
        end
    end

    while true
        if ps.nt.kind == Tokens.AT_SIGN
            next(ps)
            next(ps)
            a = INSTANCE(ps)
            a = EXPR{IDENTIFIER}(EXPR[], a.span + 1, Variable[], string("@", a.val))
            push!(args, a)
        elseif ps.nt.kind == Tokens.LPAREN
            next(ps)
            a = EXPR{InvisBrackets}(EXPR[INSTANCE(ps)], -ps.t.startbyte, Variable[], "")
            @catcherror ps startbyte push!(a.args, @default ps @closer ps paren parse_expression(ps))
            next(ps)
            push!(a.args, INSTANCE(ps))
            a.span += ps.nt.startbyte
            push!(args, a)
        elseif ps.nt.kind == Tokens.EX_OR
            @catcherror ps startbyte a = @closer ps comma parse_expression(ps)
            push!(args, a)
        elseif !colon && isoperator(ps.nt) && ps.ndot
            next(ps)
            push!(args, EXPR{OPERATOR{precedence(ps.t),ps.t.kind,false}}(EXPR[], ps.nt.startbyte - ps.t.startbyte - 1, Variable[], ""))
        else
            next(ps)
            push!(args, INSTANCE(ps))
        end

        if ps.nt.kind == Tokens.DOT
            next(ps)
            push!(args, INSTANCE(ps))
        elseif isoperator(ps.nt) && ps.ndot
            push!(args, EXPR{PUNCTUATION{Tokens.DOT}}(EXPR[], 1, Variable[], ""))
        else
            break
        end
        # if ps.nt.kind != Tokens.DOT
        #     break
        # else
        #     next(ps)
        #     push!(puncs, INSTANCE(ps))
        # end
    end
    args
end


function parse_imports(ps::ParseState)
    startbyte = ps.t.startbyte
    kw = INSTANCE(ps)
    kwt = kw isa EXPR{KEYWORD{Tokens.IMPORT}} ? Import :
          kw isa EXPR{KEYWORD{Tokens.IMPORTALL}} ? ImportAll :
          Using
    format_kw(ps)
    tk = ps.t.kind

    arg = parse_dot_mod(ps)

    if ps.nt.kind != Tokens.COMMA && ps.nt.kind != Tokens.COLON
        ret = EXPR{kwt}(EXPR[kw; arg], ps.nt.startbyte - startbyte, Variable[], "")
        ret.defs = [Variable(Expr(ret), :IMPORTS, ret)]
    elseif ps.nt.kind == Tokens.COLON
        
        ret = EXPR{kwt}(EXPR[kw;arg], 0, Variable[], "")
        t = 0

        next(ps)
        push!(ret.args, INSTANCE(ps))
        
        
        @catcherror ps startbyte arg = parse_dot_mod(ps, true)
        append!(ret.args, arg)
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.args, INSTANCE(ps))
            @catcherror ps startbyte arg = parse_dot_mod(ps, true)
            append!(ret.args, arg)
        end
        if Expr(ret).head == :toplevel
            ret.defs = [Variable(d, :IMPORTS, ret) for d in Expr(ret).args]
        else
            ret.defs = [Variable(Expr(ret), :IMPORTS, ret)]
        end
    else
        ret = EXPR{kwt}(EXPR[kw;arg], 0, Variable[], "")
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.args, INSTANCE(ps))
            @catcherror ps startbyte arg = parse_dot_mod(ps)
            append!(ret.args, arg)
        end
        ret.defs = [Variable(d, :IMPORTS, ret) for d in Expr(ret).args]
    end
    
    # Linting
    if ps.current_scope == Scope{Tokens.FUNCTION}
        push!(ps.diagnostics, Diagnostic{Diagnostics.ImportInFunction}(startbyte:ps.nt.startbyte, [], ""))
    end

    ret.span = ps.nt.startbyte - startbyte

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.EXPORT}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    ret = EXPR{Export}(EXPR[kw; parse_dot_mod(ps)], 0, Variable[], "")
    
    while ps.nt.kind == Tokens.COMMA
        next(ps)
        push!(ret.args, INSTANCE(ps))
        @catcherror ps startbyte arg = parse_dot_mod(ps)[1]
        push!(ret.args, arg)
    end
    ret.span = ps.nt.startbyte - startbyte

    # Linting

    # check for duplicates
    let idargs = filter(a -> a isa EXPR{IDENTIFIER}, ret.args)
        if length(idargs) != length(unique((a -> a.val).(idargs)))
            push!(ps.diagnostics, Diagnostic{Diagnostics.DuplicateArgument}(startbyte:ps.nt.startbyte, [], ""))
        end
    end
    if ps.current_scope == Scope{Tokens.FUNCTION}
        push!(ps.diagnostics, Diagnostic{Diagnostics.ImportInFunction}(startbyte:ps.nt.startbyte, [], ""))
    end
    return ret
end



