function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    arg = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps arg = @default ps parse_block(ps, arg, start_col, Tokens.Kind[Tokens.END], true)

    next(ps)
    return EXPR{Begin}(EXPR[kw; arg; INSTANCE(ps)], Variable[], "")
end


"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token.
Returns `ps` the token before the closing `end`, the calling function is
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR{Block}, start_col = 0, closers = Tokens.Kind[Tokens.END, Tokens.CATCH, Tokens.FINALLY], docable = false)
    start_line = ps.nt.startpos[1]
    start_col = ps.nt.startpos[2]

    # Parsing
    while !(ps.nt.kind in closers) && !ps.errored
        ps.nt.startpos[1] != start_line && ps.ws.kind == NewLineWS && format_indent(ps, start_col)
        if docable
            @catcherror ps a = @closer ps block parse_doc(ps)
        else
            @catcherror ps a = @closer ps block parse_expression(ps)
        end
        push!(ret, a)
    end
    return ret
end
