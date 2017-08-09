parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORT}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORTALL}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.USING}}) = parse_imports(ps)

parse_kw(ps::ParseState, ::Type{Val{Tokens.MODULE}}) = parse_module(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.BAREMODULE}}) = parse_module(ps)

function parse_module(ps::ParseState)
    # Parsing
    kw = INSTANCE(ps)
    if ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
    else
        @catcherror ps arg = @precedence ps 15 @closer ps block @closer ps ws parse_expression(ps)
    end

    block = EXPR{Block}(EXPR[], "")
    @scope ps Scope{Tokens.MODULE} @default ps while ps.nt.kind !== Tokens.END
        @catcherror ps a = @closer ps block parse_doc(ps)
        push!(block, a)
    end

    # Construction
    next(ps)
    ret = EXPR{(kw isa EXPR{KEYWORD{Tokens.MODULE}} ? ModuleH : BareModule)}(EXPR[kw, arg, block, INSTANCE(ps)], "")
    return ret
end

function parse_dot_mod(ps::ParseState, is_colon = false)
    args = EXPR[]

    while ps.nt.kind == Tokens.DOT || ps.nt.kind == Tokens.DDOT || ps.nt.kind == Tokens.DDDOT
        next(ps)
        d = INSTANCE(ps)
        if d isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
        elseif d isa EXPR{OPERATOR{ColonOp,Tokens.DDOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
        elseif d isa EXPR{OPERATOR{DddotOp,Tokens.DDDOT,false}}
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
            push!(args, EXPR{OPERATOR{DotOp,Tokens.DOT,false}}(EXPR[], 1, 1:1, ""))
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
            push!(args, EXPR{IDENTIFIER}(EXPR[], a.fullspan + 1, 1:(span(a) + 1), string("@", a.val)))
        elseif ps.nt.kind == Tokens.LPAREN
            next(ps)
            a = EXPR{InvisBrackets}(EXPR[INSTANCE(ps)], "")
            @catcherror ps push!(a, @default ps @closer ps paren parse_expression(ps))
            next(ps)
            push!(a, INSTANCE(ps))
            push!(args, a)
        elseif ps.nt.kind == Tokens.EX_OR
            @catcherror ps a = @closer ps comma parse_expression(ps)
            push!(args, a)
        elseif !is_colon && isoperator(ps.nt) && ps.ndot
            next(ps)
            push!(args, EXPR{OPERATOR{precedence(ps.t),ps.t.kind,false}}(EXPR[], ps.nt.startbyte - ps.t.startbyte - 1, 1 + (0:ps.t.endbyte - ps.t.startbyte), ""))
        else
            next(ps)
            push!(args, INSTANCE(ps))
        end

        if ps.nt.kind == Tokens.DOT
            next(ps)
            push!(args, INSTANCE(ps))
        elseif isoperator(ps.nt) && ps.ndot
            push!(args, EXPR{PUNCTUATION{Tokens.DOT}}(EXPR[], 1, 1:1, ""))
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
    kw = INSTANCE(ps)
    kwt = kw isa EXPR{KEYWORD{Tokens.IMPORT}} ? Import :
          kw isa EXPR{KEYWORD{Tokens.IMPORTALL}} ? ImportAll :
          Using
    tk = ps.t.kind

    arg = parse_dot_mod(ps)

    if ps.nt.kind != Tokens.COMMA && ps.nt.kind != Tokens.COLON
        ret = EXPR{kwt}(EXPR[kw; arg], "")
    elseif ps.nt.kind == Tokens.COLON

        ret = EXPR{kwt}(EXPR[kw;arg], "")
        t = 0

        next(ps)
        push!(ret, INSTANCE(ps))

        @catcherror ps arg = parse_dot_mod(ps, true)
        append!(ret, arg)
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret, INSTANCE(ps))
            @catcherror ps arg = parse_dot_mod(ps, true)
            append!(ret, arg)
        end
    else
        ret = EXPR{kwt}(EXPR[kw;arg], "")
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret, INSTANCE(ps))
            @catcherror ps arg = parse_dot_mod(ps)
            append!(ret, arg)
        end
    end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.EXPORT}})
    # Parsing
    kw = INSTANCE(ps)
    ret = EXPR{Export}(EXPR[kw; parse_dot_mod(ps)], "")

    while ps.nt.kind == Tokens.COMMA
        next(ps)
        push!(ret, INSTANCE(ps))
        @catcherror ps arg = parse_dot_mod(ps)[1]
        push!(ret, arg)
    end

    return ret
end



