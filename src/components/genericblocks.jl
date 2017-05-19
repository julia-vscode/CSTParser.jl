function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte arg = @default ps parse_block(ps, start_col)

    next(ps)
    return EXPR(Begin, SyntaxNode[kw; arg; INSTANCE(ps)], ps.nt.startbyte - startbyte)
end


"""
    parse_block(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, start_col = 0; ret::EXPR = EXPR(Block, [], 0), closers = [Tokens.END, Tokens.CATCH, Tokens.FINALLY])
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
    # ps.nt.startpos[1] != start_line && format_indent(ps, start_col - 4)
    # if deadcode > -1
    #     push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(deadcode:ps.nt.startbyte, []))
    # end

    ret.span = ps.nt.startbyte - startbyte
    return ret
end


function next(x::EXPR, s::Iterator{:invisiblebrackets})
    if s.i == 1
        return first(x.punctuation), next_iter(s)
    elseif s.i == 2
        return x.args[1], next_iter(s)
    elseif s.i == 3
        return last(x.punctuation), next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:block})
    if !isempty(x.punctuation) && first(x.punctuation) isa PUNCTUATION{Tokens.COMMA}
        if isodd(s.i)
            return x.args[div(s.i + 1, 2)], next_iter(s)
        else
            return x.punctuation[div(s.i, 2)], next_iter(s)
        end
    elseif length(x.punctuation) == 2
        if s.i == 1
            return x.punctuation[1], next_iter(s)
        elseif s.i == s.n
            return x.punctuation[2], next_iter(s)
        else
            return x.args[s.i - 1], next_iter(s)
        end
    end

    return x.args[s.i], next_iter(s)
end

function next(x::EXPR, s::Iterator{:begin})
    if s.i == 1
        return x.head, next_iter(s)
    elseif s.i == 2
        return x.args[1], next_iter(s)
    elseif s.i == 3
        return x.punctuation[1], next_iter(s)
    end
end

function next(x::EXPR, s::Iterator{:toplevelblock})
    if isempty(x.punctuation)
        return x.args[s.i], next_iter(s)
    else     
        if isodd(s.i)
            return x.args[div(s.i + 1, 2)], next_iter(s)
        else
            return x.punctuation[div(s.i, 2)], next_iter(s)
        end
    end
end



