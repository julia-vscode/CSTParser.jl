function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONST}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    # Construction
    ret = EXPR{Const}(EXPR[kw, arg], Variable[], "")

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps arg = parse_expression(ps)

    # Construction
    # if arg isa EXPR{TupleH} && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
    #     ret = EXPR(Global, [kw, arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    # else
    ret = EXPR{Global}(EXPR[kw, arg], Variable[], "")
    # end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps arg = @default ps parse_expression(ps)

    # Construction
    # if arg isa EXPR && arg.head == TUPLE && first(arg.punctuation) isa PUNCTUATION{Tokens.COMMA}
    #     ret = EXPR(Local, [kw, arg.args...], ps.nt.startbyte - startbyte, arg.punctuation)
    # else
    ret = EXPR{Local}(EXPR[kw, arg], Variable[], "")
    # end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.RETURN}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps args = @default ps closer(ps) ? NOTHING : parse_expression(ps)

    # Construction
    ret = EXPR{Return}(EXPR[kw, args], Variable[], "")

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.END}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "end")
    if !ps.closer.square
        ps.errored = true
        return EXPR{ERROR}(EXPR[], Variable[], "incorrect use of end")
    end
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSE}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "else")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], 0, Variable[], "incorrect use of else")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.ELSEIF}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "elseif")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], 0, Variable[], "incorrect use of else")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CATCH}})
    ret = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], "catch")
    ps.errored = true
    return EXPR{ERROR}(EXPR[], 0, Variable[], "incorrect use of catch")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FINALLY}})
    ret = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, :finally)
    ps.errored = true
    return EXPR{ERROR}(EXPR[], 0, Variable[], "incorrect use of finally")
end
