function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    arg = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte arg = @default ps parse_block(ps, arg, start_col)

    next(ps)
    return EXPR{Begin}(EXPR[kw; arg; INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
end


"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR{Block}, start_col = 0, closers = Tokens.Kind[Tokens.END, Tokens.CATCH, Tokens.FINALLY])
    startbyte = ps.nt.startbyte
    start_line = ps.nt.startpos[1]
    start_col = ps.nt.startpos[2]

    deadcode = -1
    # Parsing
    while !(ps.nt.kind in closers) && !ps.errored
        ps.nt.startpos[1] != start_line && ps.ws.kind == NewLineWS && format_indent(ps, start_col)
        @catcherror ps startbyte a = @closer ps block parse_expression(ps)
        push!(ret.args, a)

        if a isa EXPR{Return} && !(ps.nt.kind in closers)
            deadcode = ps.nt.startbyte
        end
    end

    # Linting
    ps.nt.startpos[1] != start_line && format_indent(ps, start_col - 4)
    if deadcode > -1
        push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(deadcode:ps.nt.startbyte, [], ""))
    end

    ret.span = ps.nt.startbyte - startbyte
    return ret
end
