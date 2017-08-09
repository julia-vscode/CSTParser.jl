function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    kw = INSTANCE(ps)
    arg = EXPR{Block}(EXPR[], 0, 1:0, "")
    @catcherror ps @default ps parse_block(ps, arg)
    next(ps)

    ret = EXPR{Quote}(EXPR[kw, arg, INSTANCE(ps)], "")
    return ret
end
