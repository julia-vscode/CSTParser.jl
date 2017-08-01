function longest_common_prefix(prefixa, prefixb)
    maxplength = min(sizeof(prefixa), sizeof(prefixb))
    maxplength == 0 && return ""
    idx = findfirst(i->(prefixa[i] != prefixb[i]),1:maxplength)
    idx = idx == 0 ? maxplength : idx - 1
    prefixa[1:idx]
end

function skip_to_nl(str, idxend)
    while (idxend < length(str)) && str[idxend] != '\n'
        idxend = nextind(str, idxend)
    end
    idxend
end

tostr(buf::IOBuffer) = unescape_string(String(take!(buf)))

"""
parse_string_or_cmd(ps)

When trying to make an `INSTANCE` from a string token we must check for
interpolating operators.
"""
function parse_string_or_cmd(ps::ParseState, prefixed = false)
    sfullspan = ps.nt.startbyte - ps.t.startbyte
    sspan = 1 + (0:(ps.t.endbyte-ps.t.startbyte))

    istrip = (ps.t.kind == Tokens.TRIPLE_STRING) || (ps.t.kind == Tokens.TRIPLE_CMD)
    iscmd = ps.t.kind == Tokens.CMD || ps.t.kind == Tokens.TRIPLE_CMD

    if ps.errored
        return EXPR{ERROR}([], 0, [], ps.t.val)
    end

    lcp = nothing
    exprs_to_adjust = EXPR[]
    function adjust_lcp(expr, last = false)
        push!(exprs_to_adjust, expr)
        str = expr.val
        (isempty(str) || (lcp != nothing && isempty(lcp))) && return
        (last && str[end] == '\n') && return (lcp = "")
        idxstart, idxend = 2, 1
        while idxend < sizeof(str) && (lcp == nothing || !isempty(lcp))
            idxend = skip_to_nl(str, idxend)
            idxstart = nextind(str, idxend)
            while idxend < sizeof(str)
                c = str[nextind(str, idxend)]
                if c == ' ' || c == '\t'
                    idxend += 1
                elseif c == '\n'
                    # All whitespace lines in the middle are ignored
                    idxend += 1
                    idxstart = idxend+1
                else
                    prefix = str[idxstart:idxend]
                    lcp = lcp === nothing ? prefix : longest_common_prefix(lcp, prefix)
                    break
                end
            end
        end
        if idxstart != idxend + 1
            prefix = str[idxstart:idxend]
            lcp = lcp === nothing ? prefix : longest_common_prefix(lcp, prefix)
        end
    end

    # there are interpolations in the string
    if prefixed != false || iscmd
        val = istrip ? ps.t.val[4:end-3] : ps.t.val[2:end-1]
        expr = EXPR{LITERAL{ps.t.kind}}(Expr[], sfullspan, sspan, Variable[],
            iscmd ? replace(val, "\\`", "`") :
                    replace(val, "\\\"", "\""))
        if istrip
            adjust_lcp(expr)
            ret = EXPR{StringH}(EXPR[expr], sfullspan, sspan, Variable[], "")
        else
            return expr
        end
    else
        ret = EXPR{StringH}(EXPR[], sfullspan, sspan, Variable[], "")
        input = IOBuffer(ps.t.val)
        seek(input, istrip ? 3 : 1)
        b = IOBuffer()
        while true
            if eof(input)
                lspan = position(b)
                str = tostr(b)[1:end-(istrip?3:1)]
                ex = EXPR{LITERAL{Tokens.STRING}}(EXPR[], lspan, 1:lspan, Variable[], str)
                push!(ret.args, ex); istrip && adjust_lcp(ex, true)
                break
            end
            c = read(input, Char)
            if c == '\\'
                write(b, c)
                write(b, read(input, Char))
            elseif c == '$'
                lspan = position(b)
                str = tostr(b)
                if !isempty(str)
                    ex = EXPR{LITERAL{Tokens.STRING}}(EXPR[], lspan+1, 1:(lspan+1), Variable[], str)
                    push!(ret.args, ex); istrip && adjust_lcp(ex)
                end
                op = EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}}(EXPR[], 1, 1:1, Variable[], "\$")
                call = EXPR{UnarySyntaxOpCall}(EXPR[op], Variable[], "")
                if peekchar(input) == '('
                    lparen = EXPR{PUNCTUATION{Tokens.LPAREN}}(EXPR[], 1, 1:1, Variable[], "(")
                    rparen = EXPR{PUNCTUATION{Tokens.RPAREN}}(EXPR[], 1, 1:1, Variable[], "(")
                    skip(input, 1)
                    ps1 = ParseState(input)
                    @catcherror ps interp = @closer ps1 paren parse_expression(ps1)
                    push!(call,
                        EXPR{InvisBrackets}([lparen, interp, rparen], Variable[], ""))
                    push!(ret.args, call)
                    # Compared to flisp/JuliaParser, we have an extra lookahead token,
                    # so we need to back up one here
                    seek(input, ps1.nt.startbyte+1)
                else
                    pos = position(input)
                    ps1 = ParseState(input)
                    next(ps1)
                    t = INSTANCE(ps1)
                    push!(call, t)
                    push!(ret.args, call)
                    seek(input, pos+t.fullspan-length(ps1.ws.val))
                end
            else
                write(b, c)
            end
        end
    end

    single_string_T = Union{EXPR{LITERAL{Tokens.STRING}},EXPR{LITERAL{ps.t.kind}}}
    if istrip
        if lcp != nothing && !isempty(lcp)
            for expr in exprs_to_adjust
                expr.val = replace(expr.val, "\n$lcp", "\n")
            end
        end
        # Drop leading newline
        if ret.args[1] isa single_string_T &&
                !isempty(ret.args[1].val) && ret.args[1].val[1] == '\n'
            ret.args[1].val = ret.args[1].val[2:end]
        end
    end

    ret = (length(ret.args) == 1 && ret.args[1] isa single_string_T) ? ret.args[1] : ret
    update_span!(ret)

    return ret
end
