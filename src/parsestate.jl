type ParseState
    l::Lexer
    done::Bool
    lt::Token
    t::Token
    nt::Token
    lws::Token
    ws::Token
    nws::Token
    ws_delim::Bool
end
function ParseState(str::String)
    next(ParseState(tokenize(str), false, Token(), Token(), Token(), Token(), Token(), Token(), false))
end

function Base.show(io::IO, ps::ParseState)
    println(io, "ParseState $(ps.done ? "finished " : "")at $(ps.l.current_pos)")
    println(io, "token - (ws)")
    println(io,"last    : ", ps.lt, " ($(length(ps.lws.val)))")
    println(io,"current : ", ps.t, " ($(length(ps.ws.val)))")
    println(io,"next    : ", ps.nt, " ($(length(ps.nws.val)))")
end
peekchar(ps::ParseState) = peekchar(ps.l)

function next(ps::ParseState)
    ps.lt = ps.t
    ps.t = ps.nt
    ps.lws = ps.ws
    ps.ws = ps.nws
    ps.nt, ps.done  = next(ps.l, ps.done)
    if iswhitespace(peekchar(ps.l))
        ps.nws, ps.done = next(ps.l, ps.done)
    else
        ps.nws = Token()
    end
    return ps
end