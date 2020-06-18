function longest_common_prefix(prefixa, prefixb)
    maxplength = min(sizeof(prefixa), sizeof(prefixb))
    maxplength == 0 && return ""
    idx = findfirst(i->(prefixa[i] != prefixb[i]), 1:maxplength)
    idx = idx === nothing ? maxplength : idx - 1
    prefixa[1:idx]
end

function skip_to_nl(str, idxend)
    while (idxend < sizeof(str)) && str[idxend] != '\n'
        idxend = nextind(str, idxend)
    end
    idxend > sizeof(str) ? prevind(str, idxend) : idxend
end

tostr(buf::IOBuffer) = _unescape_string(String(take!(buf)))

"""
parse_string_or_cmd(ps)

When trying to make an `INSTANCE` from a string token we must check for
interpolating opoerators.
"""
function parse_string_or_cmd(ps::ParseState, prefixed = false)
    sfullspan = ps.nt.startbyte - ps.t.startbyte
    sspan = 1 + ps.t.endbyte - ps.t.startbyte

    istrip = (kindof(ps.t) === Tokens.TRIPLE_STRING) || (kindof(ps.t) === Tokens.TRIPLE_CMD)
    iscmd = kindof(ps.t) === Tokens.CMD || kindof(ps.t) === Tokens.TRIPLE_CMD

    lcp = nothing
    exprs_to_adjust = []
    function adjust_lcp(expr::EXPR, last = false)
        if isliteral(expr)
            push!(exprs_to_adjust, expr)
            str = valof(expr)
            (isempty(str) || (lcp !== nothing && isempty(lcp))) && return
            (last && str[end] == '\n') && return (lcp = "")
            idxstart, idxend = 2, 1
            while nextind(str, idxend) - 1 < sizeof(str) && (lcp === nothing || !isempty(lcp))
                idxend = skip_to_nl(str, idxend)
                idxstart = nextind(str, idxend)
                while nextind(str, idxend) - 1 < sizeof(str)
                    c = str[nextind(str, idxend)]
                    if c == ' ' || c == '\t'
                        idxend += 1
                    elseif c == '\n'
                        # All whitespace lines in the middle are ignored
                        idxend += 1
                        idxstart = idxend + 1
                    else
                        prefix = str[idxstart:idxend]
                        lcp = lcp === nothing ? prefix : longest_common_prefix(lcp, prefix)
                        break
                    end
                end
            end
            if idxstart != nextind(str, idxend)
                prefix = str[idxstart:idxend]
                lcp = lcp === nothing ? prefix : longest_common_prefix(lcp, prefix)
            end
        end
    end

    # there are interpolations in the string
    t_str = val(ps.t, ps)
    if istrip && length(t_str) == 6
        if iscmd
            return wrapwithcmdmacro(EXPR(:TRIPLESTRING , sfullspan, sspan, ""))
        else
            return EXPR(:TRIPLESTRING, sfullspan, sspan, "")
        end
    elseif length(t_str) == 2
        if iscmd
            return wrapwithcmdmacro(EXPR(:STRING , sfullspan, sspan, ""))
        else
            return EXPR(:STRING, sfullspan, sspan, "")
        end
    elseif prefixed != false || iscmd
        _val = istrip ? t_str[4:prevind(t_str, sizeof(t_str), 3)] : t_str[2:prevind(t_str, sizeof(t_str))]
        if iscmd
            _val = replace(_val, "\\\\" => "\\")
            _val = replace(_val, "\\`" => "`")
        else
            if endswith(_val, "\\\\")
                _val = _val[1:end - 1]
            end
            _val = replace(_val, "\\\"" => "\"")
        end
        expr = EXPR(istrip ? :TRIPLESTRING : :STRING, sfullspan, sspan, _val)
        if istrip
            adjust_lcp(expr)
            ret = EXPR(:string, EXPR[expr], nothing, sfullspan, sspan)
        else
            return iscmd ? wrapwithcmdmacro(expr) : expr
        end
    else
        ret = EXPR(:string, EXPR[], EXPR[], sfullspan, sspan)
        input = IOBuffer(t_str)
        startbytes = istrip ? 3 : 1
        seek(input, startbytes)
        b = IOBuffer()
        while !eof(input)
            c = read(input, Char)
            if c == '\\'
                write(b, c)
                write(b, read(input, Char))
            elseif c == '$'
                lspan = position(b)
                str = tostr(b)
                ex = EXPR(:STRING, lspan + startbytes, lspan + startbytes, str)
                !isempty(str) && push!(ret, ex)
                istrip && adjust_lcp(ex)
                startbytes = 0
                op = EXPR(:OPERATOR, 1, 1, "\$")
                if peekchar(input) == '('
                    lparen = EXPR(:LPAREN, 1, 1)
                    rparen = EXPR(:RPAREN, 1, 1)
                    skip(input, 1)
                    ps1 = ParseState(input)

                    if kindof(ps1.nt) === Tokens.RPAREN
                        push!(ret, EXPR(:ERRORTOKEN, EXPR[], nothing))
                        pushtotrivia!(ret, op)
                        pushtotrivia!(ret, lparen)
                        pushtotrivia!(ret, rparen)
                        skip(input, 1)
                    else
                        interp_val = @closer ps1 :paren parse_expression(ps1)
                        push!(ret, interp_val)
                        pushtotrivia!(ret, op)
                        pushtotrivia!(ret, lparen)
                        pushtotrivia!(ret, rparen)
                        seek(input, ps1.nt.startbyte + 1)
                    end
                    # Compared to flisp/JuliaParser, we have an extra lookahead token,
                    # so we need to back up one here
                elseif Tokenize.Lexers.iswhitespace(peekchar(input)) || peekchar(input) === '#'
                    push!(ret, mErrorToken(ps, op, StringInterpolationWithTrailingWhitespace))
                else
                    pos = position(input)
                    ps1 = ParseState(input)
                    next(ps1)
                    if kindof(ps1.t) === Tokens.WHITESPACE
                        error("Unexpecte whitespace after \$ in String")
                    else
                        t = INSTANCE(ps1)
                    end
                    # Attribute trailing whitespace to the string
                    t = adjustspan(t)
                    push!(ret, t)
                    pushtotrivia!(ret, op)
                    seek(input, pos + t.fullspan)
                end
            else
                write(b, c)
            end
        end

        # handle last String section
        lspan = position(b)
        if b.size == 0
            ex = mErrorToken(ps, Unknown)
            push!(ret, ex)
        else
            str = tostr(b)
            if istrip
                str = str[1:prevind(str, lastindex(str), 3)]
                # only mark non-interpolated triple strings
                ex = EXPR(length(ret) == 0 ? :TRIPLESTRING : :STRING, lspan + ps.nt.startbyte - ps.t.endbyte - 1 + startbytes, lspan + startbytes, str)
                adjust_lcp(ex, true)
            else
                str = str[1:prevind(str, lastindex(str))]
                ex = EXPR(:STRING, lspan + ps.nt.startbyte - ps.t.endbyte - 1 + startbytes, lspan + startbytes, str)
            end
            !isempty(str) && push!(ret, ex)
        end
        

    end

    single_string_T = (:STRING, :TRIPLESTRING, literalmap(kindof(ps.t)))
    if istrip
        if lcp !== nothing && !isempty(lcp)
            for expr in exprs_to_adjust
                for (i, a) in enumerate(ret.args)
                    if expr == a
                        ret.args[i].val = replace(valof(expr), "\n$lcp" => "\n")
                        break
                    end
                end
            end
        end
        # Drop leading newline
        if !isempty(ret.args) && isliteral(ret.args[1]) && headof(ret.args[1]) in single_string_T &&
                !isempty(valof(ret.args[1])) && valof(ret.args[1])[1] == '\n'
            ret.args[1] = dropleadlingnewline(ret.args[1])
        end
    end

    if (length(ret.args) == 1 && isliteral(ret.args[1]) && headof(ret.args[1]) in single_string_T)
        ret = ret.args[1]
    end
    update_span!(ret)

    return iscmd ? wrapwithcmdmacro(ret) : ret
end

function adjustspan(x::EXPR)
    x.fullspan = x.span
    return x
end

dropleadlingnewline(x::EXPR) = EXPR(headof(x), x.fullspan, x.span, valof(x)[2:end])

wrapwithcmdmacro(x) =EXPR(:macrocall, EXPR[EXPR(:globalrefcmd, 0, 0), EXPR(:NOTHING, 0, 0), x])

"""
    parse_prefixed_string_cmd(ps::ParseState, ret::EXPR)

Parse prefixed strings and commands such as `pre"text"`.
"""
function parse_prefixed_string_cmd(ps::ParseState, ret::EXPR)
    arg = parse_string_or_cmd(next(ps), ret)

    if ret.head === :IDENTIFIER && valof(ret) == "var" && isstringliteral(arg) && VERSION > v"1.3.0-"
        return EXPR(:NONSTDIDENTIFIER, EXPR[ret, arg], nothing)
    elseif headof(arg) === :macrocall && headof(arg.args[1]) === :globalrefcmd
        mname = EXPR(:macroname, EXPR[EXPR(:ATSIGN, 0, 0), EXPR(:IDENTIFIER, 0, 0, string(valof(ret), "_cmd"))], EXPR[ret])
        return EXPR(:macrocall, EXPR[mname, EXPR(:NOTHING, 0, 0), arg.args[3]], nothing)
    elseif is_getfield(ret)
        if headof(ret.args[2]) === :quote || headof(ret.args[2]) === :quotenode
            ret.args[2].args[1] = setparent!(EXPR(:macroname, EXPR[EXPR(:ATSIGN, 0, 0), EXPR(:IDENTIFIER, 0, 0, string(valof(ret.args[2].args[1]), "_str"))], EXPR[ret.args[2].args[1]]), ret.args[2])
        else
            ret.args[2] = setparent!(EXPR(:macroname, EXPR[EXPR(:ATSIGN, 0, 0), EXPR(:IDENTIFIER, 0, 0, string(valof(ret.args[2].args[1]), "_str"))], EXPR[ret.args[2]]), ret.args[2])
        end

        return EXPR(:macrocall, EXPR[ret, EXPR(:NOTHING, 0, 0), arg], nothing)
    else
        mname = EXPR(:macroname, EXPR[EXPR(:ATSIGN, 0, 0), EXPR(:IDENTIFIER, 0, 0, string(valof(ret), "_str"))], EXPR[ret])
        return EXPR(:macrocall, EXPR[mname, EXPR(:NOTHING, 0, 0), arg], nothing)
    end
end