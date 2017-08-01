function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    arg = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps @default ps parse_block(ps, arg)
    next(ps)

    # Construction
    ret = EXPR{Quote}(EXPR[kw, arg, INSTANCE(ps)], Variable[], "")

    return ret
end
