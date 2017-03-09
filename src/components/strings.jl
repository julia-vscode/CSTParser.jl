"""
    parse_string(ps)

When trying to make an `INSTANCE` from a string token we must check for 
interpolating operators.
"""
function parse_string(ps::ParseState, prefixed = false)
    span = ps.nt.startbyte - ps.t.startbyte
    offset = ps.t.startbyte
    istrip = ps.t.kind == Tokens.TRIPLE_STRING
    if istrip
        lit = LITERAL{ps.t.kind}(span, offset, startswith(ps.t.val, "\"\"\"\n") ? ps.t.val[5:end-3] : ps.t.val[4:end-3])
    else
        lit = LITERAL{ps.t.kind}(span, offset, ps.t.val[2:end-1])
    end

    # there are interpolations in the string
    if ismatch(r"(?<!\\)\$", lit.val) && !prefixed
        io = IOBuffer(lit.val)
        ret = EXPR(STRING, [], lit.span)
        pos = 1
        lc = ' '
        while !eof(io)
            io2 = IOBuffer()
            while !eof(io)
                c = read(io, Char)
                # pos += 1
                write(io2, c)
                if c == '$' && lc != '\\'
                    break
                end
                lc = c
            end
            str1 = String(take!(io2))
            pos+=endof(str1)

            if last(str1) === '$' && (length(str1) ==1 || str1[end-1] != '\\')#&& str1[endof(str1)-1] != '''
                push!(ret.args, LITERAL{Tokens.STRING}(endof(str1) - 1, 0, unescape_string(str1[1:end-1])))
                if peekchar(io) == '('
                    # interp = EXPR(BLOCK, [])
                    ps1 = ParseState(lit.val[pos+1:end])
                    interp = @closer ps1 paren parse_expression(ps1)
                    push!(ret.args, interp)
                    skip(io, interp.span + 2 - (ps1.ws.endbyte - ps1.ws.startbyte + 1))
                    pos += interp.span + 2 - (ps1.ws.endbyte - ps1.ws.startbyte + 1)
                else
                    ps1 = ParseState(lit.val[pos:end])
                    next(ps1)
                    interp = INSTANCE(ps1)
                    push!(ret.args, interp)
                    
                    skip(io, interp.span - (ps1.ws.endbyte - ps1.ws.startbyte + 0))
                    pos += interp.span - (ps1.ws.endbyte - ps1.ws.startbyte + 0)
                end
            else
                push!(ret.args, LITERAL{Tokens.STRING}(sizeof(str1) - 1, 0, unescape_string(str1)))
            end
        end
        return ret
    else
        return lit
    end
    return ret
end