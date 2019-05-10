macro addctx(t, func)
    n = length(func.args[2].args)
    insert!(func.args[2].args, n, :(pop!(ps.closer.cc)))
    pushfirst!(func.args[2].args, :(push!(ps.closer.cc, $(t))))
    return esc(func)
end

macro enterctx(ps, t)
    :(push!($(esc(ps)).closer.cc, $t))
end

macro exitctx(ps, ret)
    quote
        pop!($(esc(ps)).closer.cc)
        $(esc(ret))
    end
end

function accept_rparen(ps)
    if ps.nt.kind == Tokens.RPAREN
        return mPUNCTUATION(next(ps))
    else
        push!(ps.errors, Error((ps.ws.startbyte:ps.ws.endbyte) .+ 1 , "Expected )."))
        return mErrorToken(mPUNCTUATION(Tokens.RPAREN, 0, 0))
    end
end
accept_rparen(ps::ParseState, args) = push!(args, accept_rparen(ps))

function accept_rsquare(ps)
    if ps.nt.kind == Tokens.RSQUARE
        return mPUNCTUATION(next(ps))
    else
        push!(ps.errors, Error((ps.t.startbyte:ps.t.endbyte) .+ 1 , "Expected ]."))
        return mErrorToken(mPUNCTUATION(Tokens.RSQUARE, 0, 0))
    end
end
accept_rsquare(ps::ParseState, args) = push!(args, accept_rsquare(ps))

function accept_rbrace(ps)
    if ps.nt.kind == Tokens.RBRACE
        return mPUNCTUATION(next(ps))
    else
        push!(ps.errors, Error((ps.t.startbyte:ps.t.endbyte) .+ 1 , "Expected }."))
        return mErrorToken(mPUNCTUATION(Tokens.RBRACE, 0, 0))
    end
end
accept_rbrace(ps::ParseState, args) = push!(args, accept_rbrace(ps))

function accept_end(ps::ParseState)
    if ps.nt.kind == Tokens.END
        return mKEYWORD(next(ps))
    else
        push!(ps.errors, Error((ps.t.startbyte:ps.t.endbyte) .+ 1 , "Expected end."))
        return mErrorToken(mKEYWORD(Tokens.END, 0, 0))
    end
end
accept_end(ps::ParseState, args) = push!(args, accept_end(ps))

function accept_comma(ps)
    if ps.nt.kind == Tokens.COMMA
        return mPUNCTUATION(next(ps))
    else
        return mPUNCTUATION(Tokens.RPAREN, 0, 0)
    end
end
accept_comma(ps::ParseState, args) = push!(args, accept_comma(ps))

function recover_endmarker(ps)
    if ps.nt.kind == Tokens.ENDMARKER
        if !isempty(ps.closer.cc)
            closert = last(ps.closer.cc)
            if closert == :block
                return mErrorToken(mKEYWORD(Tokens.END, 0, 0))
            elseif closert == :paren
                return mErrorToken(mPUNCTUATION(Tokens.RPAREN, 0, 0))
            elseif closert == :square
                return mErrorToken(mPUNCTUATION(Tokens.RSQUARE, 0, 0))
            elseif closert == :brace
                return mErrorToken(mPUNCTUATION(Tokens.RBRACE, 0, 0))
            end
        end
    end
end

function requires_ws(x)
    if x.span == x.fullspan
        return mErrorToken(x)
    else
        return x
    end
end

function requires_no_ws(x)
    if x.span != x.fullspan
        return mErrorToken(x)
    else
        return x
    end
end
