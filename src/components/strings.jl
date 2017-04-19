"""
    parse_string(ps)

When trying to make an `INSTANCE` from a string token we must check for 
interpolating operators.
"""
function parse_string(ps::ParseState, prefixed = false)
    startbyte = ps.t.startbyte
    
    span = ps.nt.startbyte - ps.t.startbyte
    istrip = ps.t.kind == Tokens.TRIPLE_STRING
    if istrip
        lit = unindent_triple_string(ps)
    else
        lit = LITERAL{ps.t.kind}(span, ps.t.val[2:end - 1])
    end

    # there are interpolations in the string
    if prefixed != false
        if prefixed isa INSTANCE && prefixed.val == :r
            lit.val = replace(lit.val, "\\\"", "\"")
        end
        return lit
    elseif ismatch(r"(?<!\\)\$", lit.val)
        io = IOBuffer(lit.val)
        ret = EXPR(STRING, [], lit.span)
        lc = ' '
        while !eof(io)
            io2 = IOBuffer()
            while !eof(io)
                c = read(io, Char)
                write(io2, c)
                if c == '$' && lc != '\\'
                    break
                end
                lc = c
            end
            str1 = String(take!(io2))

            if length(str1) > 0 && last(str1) === '$' && (length(str1) == 1 || str1[chr2ind(str1, length(str1)-1)] != '\\')
                lit2 = LITERAL{Tokens.STRING}(endof(str1) - 1, unescape_string(str1[1:end - 1]))
                if !isempty(lit2.val)
                    push!(ret.args, lit2)
                end
                if peekchar(io) == '('
                    ps1 = ParseState(lit.val[io.ptr + 1:end])
                    leading_ws_span = 0
                    if ps1.nt.kind == Tokens.WHITESPACE
                        next(ps1)
                        leading_ws_span = ps1.nt.startbyte - ps1.t.startbyte
                    end
                    @catcherror ps startbyte interp = @closer ps1 paren parse_expression(ps1)
                    push!(ret.args, interp)
                    skip(io, interp.span + 2 + leading_ws_span)
                else
                    ps1 = ParseState(lit.val[io.ptr:end])
                    next(ps1)
                    interp = INSTANCE(ps1)
                    push!(ret.args, interp)
                    
                    skip(io, interp.span - length(ps1.ws.val))
                end
            else
                push!(ret.args, LITERAL{Tokens.STRING}(sizeof(str1) - 1, unescape_string(str1)))
            end
        end
        return ret
    else
        lit.val = unescape_string(lit.val)
        return lit
    end
    ret.span = span
    return ret
end


function unindent_triple_string(ps::ParseState)
    indent = -1
    val = startswith(ps.t.val, "\"\"\"\n") ? ps.t.val[5:end - 3] : ps.t.val[4:end - 3]
    io = IOBuffer(val)
    while !eof(io)
        c = readuntil(io, '\n')
        eof(io) && break
        peekchar(io) == '\n' && skip(io, 1)
        cnt = 0
        while iswhitespace(peekchar(io)) && peekchar(io) != '\n'
            read(io, Char)
            cnt += 1
        end
        indent = indent == -1 ? cnt : min(indent, cnt)
    end
    if indent > -1
        val = Base.unindent(val, indent)
    end
    lit = LITERAL{ps.t.kind}(ps.nt.startbyte - ps.t.startbyte - ps.ndot, val)
end

_start_string(x::EXPR) = Iterator{:string}(1, 1)
next(x::EXPR, s::Iterator{:string}) = x, +s

next(x::EXPR, s::Iterator{:x_str}) = x.args[s.i], +s



