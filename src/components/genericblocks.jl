function parse_begin(ps::ParseState)
    # Parsing
    kw = INSTANCE(ps)
    blockargs = Any[]
    @catcherror ps arg = @default ps parse_block(ps, blockargs, (Tokens.END,), true)

    next(ps)
    return EXPR{Begin}(Any[kw, EXPR{Block}(blockargs), INSTANCE(ps)])
end

function parse_quote(ps::ParseState)
    kw = INSTANCE(ps)
    blockargs = Any[]
    @catcherror ps @default ps parse_block(ps, blockargs)
    next(ps)

    ret = EXPR{Quote}(Any[kw, EXPR{Block}(blockargs), INSTANCE(ps)])
    return ret
end

"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token.
Returns `ps` the token before the closing `end`, the calling function is
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR{Block}, closers = (Tokens.END,), docable = false)
    # Parsing
    parse_block(ps, ret.args, closers, docable)
    update_span!(ret)
    return 
end


function parse_block(ps::ParseState, ret::Vector{Any}, closers = (Tokens.END,), docable = false)
    # Parsing
    while !(ps.nt.kind in closers) && !ps.errored
        if ps.nt.kind == Tokens.ENDMARKER
            return error_eof(ps, ps.nt.startbyte, Diagnostics.UnexpectedBlockEnd, "Unexpected end of block")
        end
        if docable
            @catcherror ps a = @closer ps block parse_doc(ps)
        else
            @catcherror ps a = @closer ps block parse_expression(ps)
        end
        push!(ret, a)
    end
    return 
end
