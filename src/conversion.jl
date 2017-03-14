import Base: Expr, Symbol
# Converts EXPR to Base.Expr
Expr{T}(x::HEAD{T}) = Symbol(lowercase(string(T)))
Expr{T}(x::KEYWORD{T}) = Symbol(lowercase(string(T)))

function Expr(x::IDENTIFIER)
    return x.val
end

function Expr{O,K,dot}(x::OPERATOR{O,K,dot}) 
    if dot
        Symbol(:.,UNICODE_OPS_REVERSE[K])
    else
        UNICODE_OPS_REVERSE[K]
    end
end

Expr(x::LITERAL{Tokens.TRUE}) = true
Expr(x::LITERAL{Tokens.FALSE}) = false

# No reason 
function Expr{T}(x::LITERAL{T})
    Base.parse(x.val)
end

function Expr(x::LITERAL{Tokens.FLOAT}) 
    Base.parse(x.val)
end

Expr(x::LITERAL{Tokens.MACRO}) = Symbol(x.val)


function Expr(x::LITERAL{Tokens.STRING}) 
    x.val
end
function Expr(x::LITERAL{Tokens.TRIPLE_STRING}) 
    x.val
end

Expr(x::QUOTENODE) = QuoteNode(Expr(x.val))

function Expr(x::EXPR)
    if x.head isa HEAD{InvisibleBrackets}
        return Expr(x.args[1])
    elseif x.head isa KEYWORD{Tokens.BEGIN}
        return Expr(x.args[1])
    elseif x.head isa KEYWORD{Tokens.ELSEIF}
        ret = Expr(:if)
        for a in x.args
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.head isa HEAD{Tokens.GENERATOR}
        ret = Expr(:generator, Expr(x.args[1]))
        for a in x.args[2:end]
            push!(ret.args, fixranges(a))
        end
        return ret
    elseif x.head isa KEYWORD{Tokens.IMMUTABLE}
        ret = Expr(:type, false)
        for a in x.args[2:end]
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.head isa KEYWORD{Tokens.BAREMODULE}
        ret = Expr(:module)
        for a in x.args
            push!(ret.args, Expr(a))
        end 
        return ret
    elseif x.head isa KEYWORD{Tokens.DO}
        ret = Expr(x.args[1])
        insert!(ret.args, 2, Expr(:->, Expr(x.args[2]), Expr(x.args[3])))
        return ret
    elseif x.head == x_STR
        return Expr(:macrocall, Symbol('@', Expr(x.args[1]), "_str"), Expr.(x.args[2:end])...)
    elseif x.head == MACROCALL
        if x.args[1] isa HEAD{:globalrefdoc}
            ret = Expr(:macrocall, GlobalRef(Core, Symbol("@doc")))
            for a in x.args[2:end]
                push!(ret.args, Expr(a))
            end
            return ret
        end
    elseif x.head isa KEYWORD{Tokens.IMPORT} || x.head isa KEYWORD{Tokens.IMPORTALL} || x.head isa KEYWORD{Tokens.USING}
        ret = Expr(Expr(x.head))
        for i = 1:(length(x.punctuation) - length(x.args) + 1)
            push!(ret.args, :.)
        end
        for a in x.args
            push!(ret.args, Expr(a))
        end 
        return ret
    elseif x.head == TOPLEVEL && !(isempty(x.punctuation)) && (x.punctuation[1] isa KEYWORD{Tokens.IMPORT} || x.punctuation[1] isa KEYWORD{Tokens.IMPORTALL} || x.punctuation[1] isa KEYWORD{Tokens.USING})
        ret = Expr(Expr(x.head))
        col = findfirst(x-> x isa OPERATOR{8, Tokens.COLON}, x.punctuation)
        ndots = 0
        while x.punctuation[ndots + 2] isa OPERATOR{15, Tokens.DOT}
            ndots += 1
        end

        if length(x.args) == 1
            a = first(x.args)
            return Expr(Expr(a.head), (:. for i = 1:ndots)..., Expr.(x.punctuation[ndots + 2:2:col])..., Expr.(a.args)...)
        end
        for a in x.args
            push!(ret.args, Expr(Expr(a.head), (:. for i = 1:ndots)..., Expr.(x.punctuation[ndots + 2:2:col])..., Expr.(a.args)...))
        end 
        return ret
    elseif x.head == CALL
        if x.args[1] isa OPERATOR{9, Tokens.MINUS} && length(x.args) ==2 && (x.args[2] isa LITERAL{Tokens.INTEGER} || x.args[2] isa LITERAL{Tokens.FLOAT})
            return -Expr(x.args[2])
        end
        ret = Expr(Expr(x.head))
        for a in (x.args)
            if a isa EXPR && a.head == PARAMETERS
                insert!(ret.args, 2, Expr(a))
            else
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.head isa KEYWORD{Tokens.FOR}
        ret = Expr(Expr(x.head))
        if x.args[1] isa EXPR && x.args[1].head == BLOCK
            ranges = Expr(:block)
            for a in x.args[1].args
                push!(ranges.args, fixranges(a))
            end
            push!(ret.args, ranges)
        else
            push!(ret.args, fixranges(x.args[1]))
        end
        for a in x.args[2:end]
            push!(ret.args, Expr(a))
        end 
        return ret
    end
    ret = Expr(Expr(x.head))
    for a in x.args
        push!(ret.args, Expr(a))
    end 
    return ret
end



fixranges(a::INSTANCE) = Expr(a)
function fixranges(a::EXPR)
    if a.head==CALL && a.args[1] isa OPERATOR{6, Tokens.IN} || a.args[1] isa OPERATOR{6, Tokens.ELEMENT_OF}
        ret = Expr(:(=))
        for x in a.args[2:end]
            push!(ret.args, Expr(x))
        end
        return ret
    else
        return Expr(a)
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
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT] = :(>>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT_EQ] = :(>>>=)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH_EQ] = :(\=)
UNICODE_OPS_REVERSE[Tokens.AND_EQ] = :(&=)
UNICODE_OPS_REVERSE[Tokens.COLON_EQ] = :(:=)
UNICODE_OPS_REVERSE[Tokens.PAIR_ARROW] = :(=>)
UNICODE_OPS_REVERSE[Tokens.APPROX] = :(~)
UNICODE_OPS_REVERSE[Tokens.EX_OR_EQ] = :($=)
UNICODE_OPS_REVERSE[Tokens.XOR_EQ] = :(⊻=)
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