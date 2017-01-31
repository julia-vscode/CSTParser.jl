import Tokenize.Lexers: peekchar, prevchar, readchar, iswhitespace, emit, emit_error, backup!, accept_batch

const empty_whitespace = Token()

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
    colon_delim::Bool
    in_paren::Bool
end
function ParseState(str::String)
    next(ParseState(tokenize(str), false, Token(), Token(), Token(), Token(), Token(), Token(), false, false, false))
end

macro with_ws_delim(ps, body)
    quote
        local tmp1 = $(esc(ps)).ws_delim
        $(esc(ps)).ws_delim = true
        out = $(esc(body))
        $(esc(ps)).ws_delim = tmp1
        out
    end
end

macro with_in_paren(ps, body)
    quote
        local tmp1 = $(esc(ps)).in_paren
        $(esc(ps)).in_paren = true
        out = $(esc(body))
        $(esc(ps)).in_paren = tmp1
        out
    end
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
    global empty_whitespace
    ps.lt = ps.t
    ps.t = ps.nt
    ps.lws = ps.ws
    ps.ws = ps.nws
    ps.nt, ps.done  = next(ps.l, ps.done)
    if iswhitespace(peekchar(ps.l)) || peekchar(ps.l)=='#'
        readchar(ps.l)
        ps.nws = lex_ws_comment(ps.l)
    else
        ps.nws = Parser.empty_whitespace
    end
    return ps
end

function lex_ws_comment(l::Lexer)
    if prevchar(l)=='#'
        read_comment(l)
    else
        accept_batch(l, iswhitespace)
    end
    while iswhitespace(peekchar(l)) || peekchar(l)=='#'
        readchar(l)
        if prevchar(l)=='#'
            read_comment(l)
        else
            accept_batch(l, iswhitespace)
        end
    end

    return emit(l, Tokens.WHITESPACE)
end

function read_comment(l::Lexer)
    if readchar(l) != '='
        while true
            c = readchar(l)
            if c == '\n' || eof(c)
                backup!(l)
                break
            end
        end
    else
        c = readchar(l) # consume the '='
        n_start, n_end = 1, 0
        while true
            if eof(c)
                return emit_error(l, Tokens.EOF_MULTICOMMENT)
            end
            nc = readchar(l)
            if c == '#' && nc == '='
                n_start += 1
            elseif c == '=' && nc == '#'
                n_end += 1
            end
            if n_start == n_end
                break
            end
            c = nc
        end
    end
end
