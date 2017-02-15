import Base: Expr, Symbol

Expr{T}(io::IOBuffer, x::INSTANCE{HEAD,T}) = Symbol(lowercase(string(T)))
Expr{T}(io::IOBuffer, x::INSTANCE{KEYWORD,T}) = Symbol(lowercase(string(T)))

function Expr(io::IOBuffer, x::INSTANCE{IDENTIFIER,Tokens.IDENTIFIER}) 
    ioout = IOBuffer()
    seek(io, x.offset)
    cnt = 0
    while Tokenize.Lexers.is_identifier_char(Tokenize.Lexers.peekchar(io)) && cnt < x.span
        cnt+=1
        write(ioout, read(io, Char))
    end
    Symbol(take!(ioout))
end

function Expr{O,K}(io::IOBuffer, x::INSTANCE{OPERATOR{O},K}) 
    UNICODE_OPS_REVERSE[K]
end

Expr(io::IOBuffer, x::INSTANCE{LITERAL,Tokens.TRUE}) = true
Expr(io::IOBuffer, x::INSTANCE{LITERAL,Tokens.FALSE}) = false
function Expr{T}(io::IOBuffer, x::INSTANCE{LITERAL,T}) 
    ioout = IOBuffer()
    seek(io, x.offset)
    cnt = 0
    while Tokenize.Lexers.is_identifier_char(Tokenize.Lexers.peekchar(io)) && cnt < x.span
        cnt+=1
        write(ioout, read(io, Char))
    end
    Base.parse(String(take!(ioout)))
end

function Expr(io::IOBuffer, x::INSTANCE{LITERAL,Tokens.STRING}) 
    ioout = IOBuffer()
    seek(io, x.offset)
    cnt = 0
    while cnt < x.span
        cnt+=1
        write(ioout, read(io, Char))
    end
    Base.parse(String(take!(ioout)))
end

function Expr(io::IOBuffer, x::INSTANCE{LITERAL,Tokens.TRIPLE_STRING}) 
    ioout = IOBuffer()
    seek(io, x.offset)
    cnt = 0
    while cnt < x.span
        cnt+=1
        write(ioout, read(io, Char))
    end
    Base.parse(String(take!(ioout)))
end

Expr(io::IOBuffer, x::INSTANCE{KEYWORD,Tokens.BAREMODULE}) = :module

Expr(io::IOBuffer, x::QUOTENODE) = QuoteNode(Expr(io::IOBuffer, x.val))

function Expr(io::IOBuffer, x::EXPR)
    if x.head==BLOCK && length(x.punctuation)==2
        return Expr(io, x.args[1])
    elseif x.head isa INSTANCE{KEYWORD,Tokens.BEGIN}
        return Expr(io, x.args[1])
    elseif x.head isa INSTANCE{KEYWORD,Tokens.ELSEIF}
        return Expr(:if, Expr.(io, x.args)...)
    elseif x.head isa INSTANCE{HEAD, Tokens.GENERATOR}
        return Expr(:generator, Expr(io, x.args[1]), fixranges.(io, x.args[2:end])...)
    elseif x.head == x_STR
        return Expr(:macrocall, string('@', Expr(io, x.args[1]), "_str"), Expr(io, x.args[2]))
    elseif x.head == MACROCALL
        if x.args[1] isa INSTANCE{HEAD, :globalrefdoc}
            return Expr(:macrocall, GlobalRef(Core, Symbol("@doc")), Expr.(io, x.args[2:end])...)
        else
            return Expr(:macrocall, Symbol('@', Expr(io, x.args[1])), Expr.(io, x.args[2:end])...)
        end
    end
    return Expr(Expr(io, x.head), Expr.(io, x.args)...)
end


function fixranges(io::IOBuffer, a::EXPR)
    if a.head==CALL && a.args[1] isa INSTANCE{OPERATOR{6}, Tokens.IN} || a.args[1] isa INSTANCE{OPERATOR{6}, Tokens.ELEMENT_OF}
        return Expr(:(=), Expr.(io, a.args[2:end])...)
    else
        return Expr(io, a)
    end
end


UNICODE_OPS_REVERSE = Dict{Tokenize.Tokens.Kind,Symbol}()
for (k,v) in Tokenize.Tokens.UNICODE_OPS
    UNICODE_OPS_REVERSE[v] = Symbol(k)
end

UNICODE_OPS_REVERSE[Tokens.EQ] = :(=)
UNICODE_OPS_REVERSE[Tokens.PLUS_EQ] = :(+=)
UNICODE_OPS_REVERSE[Tokens.MINUS_EQ] = :(-=)
UNICODE_OPS_REVERSE[Tokens.STAR_EQ] = :(*=)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH_EQ] = :(/=)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH_EQ] = :(//=)
UNICODE_OPS_REVERSE[Tokens.OR_EQ] = :(|=)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_EQ] = :(^=)
UNICODE_OPS_REVERSE[Tokens.DIVISION_EQ] = :(÷=)
UNICODE_OPS_REVERSE[Tokens.REM_EQ] = :(%=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT_EQ] = :(<<=)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT_EQ] = :(>>=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT] = :(<<)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT] = :(>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT_EQ] = :(>>>=)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH_EQ] = :(\=)
UNICODE_OPS_REVERSE[Tokens.AND_EQ] = :(&=)
UNICODE_OPS_REVERSE[Tokens.COLON_EQ] = :(:=)
UNICODE_OPS_REVERSE[Tokens.PAIR_ARROW] = :(=>)
UNICODE_OPS_REVERSE[Tokens.APPROX] = :(~)
UNICODE_OPS_REVERSE[Tokens.EX_OR_EQ] = :($=)
UNICODE_OPS_REVERSE[Tokens.RIGHT_ARROW] = :(-->)
UNICODE_OPS_REVERSE[Tokens.LAZY_OR] = :(||)
UNICODE_OPS_REVERSE[Tokens.LAZY_AND] = :(&&)
UNICODE_OPS_REVERSE[Tokens.ISSUBTYPE] = :(<:)
UNICODE_OPS_REVERSE[Tokens.GREATER_COLON] = :(>:)
UNICODE_OPS_REVERSE[Tokens.GREATER] = :(>)
UNICODE_OPS_REVERSE[Tokens.LESS] = :(<)
UNICODE_OPS_REVERSE[Tokens.GREATER_EQ] = :(>=)
UNICODE_OPS_REVERSE[Tokens.GREATER_THAN_OR_EQUAL_TO] = :(≥)
UNICODE_OPS_REVERSE[Tokens.LESS_EQ] = :(<=)
UNICODE_OPS_REVERSE[Tokens.LESS_THAN_OR_EQUAL_TO] = :(≤)
UNICODE_OPS_REVERSE[Tokens.EQEQ] = :(==)
UNICODE_OPS_REVERSE[Tokens.EQEQEQ] = :(===)
UNICODE_OPS_REVERSE[Tokens.IDENTICAL_TO] = :(≡)
UNICODE_OPS_REVERSE[Tokens.NOT_EQ] = :(!=)
UNICODE_OPS_REVERSE[Tokens.NOT_EQUAL_TO] = :(≠)
UNICODE_OPS_REVERSE[Tokens.NOT_IS] = :(!==)
UNICODE_OPS_REVERSE[Tokens.NOT_IDENTICAL_TO] = :(≢)
UNICODE_OPS_REVERSE[Tokens.IN] = :(in)
UNICODE_OPS_REVERSE[Tokens.ISA] = :(isa)
UNICODE_OPS_REVERSE[Tokens.LPIPE] = :(<|)
UNICODE_OPS_REVERSE[Tokens.RPIPE] = :(|>)
UNICODE_OPS_REVERSE[Tokens.COLON] = :(:)
UNICODE_OPS_REVERSE[Tokens.DDOT] = :(..)
UNICODE_OPS_REVERSE[Tokens.EX_OR] = :($)
UNICODE_OPS_REVERSE[Tokens.PLUS] = :(+)
UNICODE_OPS_REVERSE[Tokens.MINUS] = :(-)
UNICODE_OPS_REVERSE[Tokens.PLUSPLUS] = :(++)
UNICODE_OPS_REVERSE[Tokens.OR] = :(|)
UNICODE_OPS_REVERSE[Tokens.STAR] = :(*)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH] = :(/)
UNICODE_OPS_REVERSE[Tokens.REM] = :(%)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH] = :(\)
UNICODE_OPS_REVERSE[Tokens.AND] = :(&)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH] = :(//)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_ACCENT] = :(^)
UNICODE_OPS_REVERSE[Tokens.DECLARATION] = :(::)
UNICODE_OPS_REVERSE[Tokens.CONDITIONAL] = :(?)
UNICODE_OPS_REVERSE[Tokens.DOT] = :(.)
UNICODE_OPS_REVERSE[Tokens.NOT] = :(!)
UNICODE_OPS_REVERSE[Tokens.PRIME] = Symbol(''')
UNICODE_OPS_REVERSE[Tokens.DDDOT] = :(...)
UNICODE_OPS_REVERSE[Tokens.TRANSPOSE] = Symbol(".'")
UNICODE_OPS_REVERSE[Tokens.ANON_FUNC] = :(->)