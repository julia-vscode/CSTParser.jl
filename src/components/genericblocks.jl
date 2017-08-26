function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    # Parsing
    kw = INSTANCE(ps)
    arg = EXPR{Block}(Any[], 0, 1:0)
    @catcherror ps arg = @default ps parse_block(ps, arg, Tokens.Kind[Tokens.END], true)

    next(ps)
    return EXPR{Begin}(Any[kw; arg; INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    kw = INSTANCE(ps)
    arg = EXPR{Block}(Any[], 0, 1:0)
    @catcherror ps @default ps parse_block(ps, arg)
    next(ps)

    ret = EXPR{Quote}(Any[kw, arg, INSTANCE(ps)])
    return ret
end

"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token.
Returns `ps` the token before the closing `end`, the calling function is
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR{Block}, closers = Tokens.Kind[Tokens.END, Tokens.CATCH, Tokens.FINALLY], docable = false)
    # Parsing
    while !(ps.nt.kind in closers) && !ps.errored
        if docable
            @catcherror ps a = @closer ps block parse_doc(ps)
        else
            @catcherror ps a = @closer ps block parse_expression(ps)
        end
        push!(ret, a)
    end
    return ret
end
