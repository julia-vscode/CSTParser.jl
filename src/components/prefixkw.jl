function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    startbyte = ps.t.startbyte
    
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte arg = parse_expression(ps)

    # Construction 
    ret = EXPR(Const, [kw, arg], ps.nt.startbyte - startbyte)

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte arg = parse_expression(ps)

    # Construction
    # if arg isa EXPR{TupleH} && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
    #     ret = EXPR(Global, [kw, arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    # else
        ret = EXPR(Global, [kw, arg], ps.nt.startbyte - startbyte)
    # end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte arg = @default ps parse_expression(ps)

    # Construction
    # if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
    #     ret = EXPR(Local, [kw, arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    # else
        ret = EXPR(Local, [kw, arg], ps.nt.startbyte - startbyte)
    # end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte args = @default ps SyntaxNode[closer(ps) ? NOTHING : parse_expression(ps)]

    # Construction
    ret = EXPR(Return, [kw; args], ps.nt.startbyte - startbyte)
    
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :end)
    if !ps.closer.square
        ps.errored = true
        return ERROR{UnexpectedEnd}(ret.span, ret)
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSE}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :else)
    ps.errored = true
    return ERROR{UnexpectedElse}(ret.span, ret)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSEIF}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :elseif)
    ps.errored = true
    return ERROR{UnexpectedElseIf}(ret.span, ret)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CATCH}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :catch)
    ps.errored = true
    return ERROR{UnexpectedCatch}(ret.span, ret)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FINALLY}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :finally)
    ps.errored = true
    return ERROR{UnexpectedFinally}(ret.span, ret)
end
