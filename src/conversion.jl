import Base: Expr, Symbol
# Converts EXPR to Base.Expr
Expr{T}(x::HEAD{T}) = Symbol(lowercase(string(T)))
Expr(x::HEAD{Tokens.LBRACE}) = :cell1d
Expr{T}(x::KEYWORD{T}) = Symbol(lowercase(string(T)))

function Expr(x::IDENTIFIER)
    return x.val
end

function Expr{O, K, dot}(x::OPERATOR{O, K, dot}) 
    if dot
        Symbol(:., UNICODE_OPS_REVERSE[K])
    else
        UNICODE_OPS_REVERSE[K]
    end
end

Expr(x::LITERAL{Tokens.TRUE}) = true
Expr(x::LITERAL{Tokens.FALSE}) = false

Expr(x::ERROR) = "Parsing error"

# No reason 
function Expr{T}(x::LITERAL{T})
    Base.parse(x.val)
end

function Expr(x::LITERAL{Tokens.FLOAT}) 
    Base.parse(x.val)
end

Expr(x::LITERAL{Tokens.MACRO}) = Symbol(x.val)
# Expr(x::LITERAL{Tokens.CMD}) = x.val

Expr{K}(x::PUNCTUATION{K}) = string(K)


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
    elseif x.head isa HEAD{Tokens.GENERATOR} ||  x.head isa HEAD{Tokens.FILTER}
        ret = Expr(Expr(x.head), Expr(x.args[1]))
        for a in x.args[2:end]
            push!(ret.args, fixranges(a))
        end
        return ret
    elseif x.head == FLATTEN
        x0 = deepcopy(x)
        x0 = Expr(x0.args[1])
        r2 = x0.args[1].args[2]
        x0.args[1].args[2] = x0.args[2]
        x0.args[2] = r2
        return Expr(:flatten, x0)
    elseif x.head isa KEYWORD{Tokens.STRUCT}
        ret = Expr(:type, Expr(x.args[1]))
        for a in x.args[2:end]
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.head isa KEYWORD{Tokens.IMMUTABLE}
        ret = Expr(:type, false)
        for a in x.args[2:end]
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.head isa KEYWORD{Tokens.TYPE} && length(x.punctuation) == 2
        if x.punctuation[1] isa KEYWORD{Tokens.ABSTRACT}
            return Expr(:abstract, Expr(x.args[1]))
        elseif x.punctuation[1] isa KEYWORD{Tokens.PRIMITIVE}
            return Expr(:bitstype, Expr(x.args[1]), Expr(x.args[2]))
        end
    elseif x.head isa HEAD{Tokens.QUOTE} && 
           x.args[1] isa EXPR && 
           x.args[1].head isa HEAD{InvisibleBrackets} && 
           length(x.args[1].args[1]) == 1 &&
           (first(x.args[1].args[1]) isa OPERATOR || first(x.args[1].args[1]) isa LITERAL || first(x.args[1].args[1]) isa IDENTIFIER)
        return QuoteNode(Expr(x.args[1].args[1]))
    elseif (x.head isa KEYWORD{Tokens.GLOBAL} || x.head isa KEYWORD{Tokens.LOCAL}) && x.args[1] isa EXPR && x.args[1].head isa KEYWORD{Tokens.CONST}
        return Expr(:const, Expr(Expr(x.head), Expr.(x.args[1].args)...))
    elseif x.head isa KEYWORD{Tokens.BAREMODULE}
        ret = Expr(:module)
        for a in x.args
            push!(ret.args, Expr(a))
        end 
        return ret
    elseif x.head isa KEYWORD{Tokens.DO}
        ret = Expr(x.args[1])
        i = 2
        while length(ret.args) >= i && ret.args[i] isa Expr && ret.args[i].head == :parameters
            i += 1
        end
        insert!(ret.args, i, Expr(:->, Expr(x.args[2]), Expr(x.args[3])))
        return ret
    elseif x.head == x_STR
        if x.args[1] isa IDENTIFIER
            return Expr(:macrocall, Symbol('@', Expr(x.args[1]), "_str"), Expr.(x.args[2:end])...)
        else
            head = Expr(x.args[1])
            if head.args[2] isa QuoteNode
                head.args[2] = QuoteNode(Symbol('@', head.args[2].value, "_str"))
            end
            return Expr(:macrocall, head, Expr.(x.args[2:end])...)
        end
    elseif x.head == x_CMD
        if x.args[1] isa IDENTIFIER
            head = Symbol('@', Expr(x.args[1]), "_cmd")
        else
            head = Expr(x.args[1])
            if head.args[2] isa QuoteNode
                head.args[2] = QuoteNode(Symbol('@', head.args[2].value, "_cmd"))
            end
        end
        ret = Expr(:macrocall, head)
        for a in x.args[2:end]
            if a isa LITERAL{Tokens.CMD}
                push!(ret.args, a.val)
            else
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.head == MACROCALL
        if x.args[1] isa HEAD{:globalrefdoc}
            ret = Expr(:macrocall, GlobalRef(Core, Symbol("@doc")))
            for a in x.args[2:end]
                push!(ret.args, Expr(a))
            end
            return ret
        elseif x.args[1] isa EXPR && x.args[1].head isa OPERATOR{15, Tokens.DOT} && string(x.args[1].args[2].val.val)[1] != '@'
            x1 = deepcopy(x)
            x1.args[1].args[2].val.val = Symbol("@", x1.args[1].args[2].val.val)
            remove_first_at!(x1.args[1])
            return Expr(x1)
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
        col = findfirst(x -> x isa OPERATOR{8, Tokens.COLON}, x.punctuation)
        ndots = 0
        while x.punctuation[ndots + 2] isa OPERATOR{15, Tokens.DOT}
            ndots += 1
        end

        if length(x.args) == 1
            a = first(x.args)
            aa = Expr(a)
            return Expr(Expr(a.head), (:. for i = 1:ndots)..., Expr.(x.punctuation[ndots + 2:2:col])..., aa.args...)
        end
        for a in x.args
            aa = Expr(a)
            push!(ret.args, Expr(Expr(a.head), (:. for i = 1:ndots)..., Expr.(x.punctuation[ndots + 2:2:col])..., aa.args...))

        end 
        return ret
    elseif x.head == CALL || x.head == CURLY || x.head == TYPED_VCAT
        if x.head == CALL && x.args[1] isa OPERATOR{9, Tokens.MINUS} && length(x.args) == 2 && (x.args[2] isa LITERAL{Tokens.INTEGER} || x.args[2] isa LITERAL{Tokens.FLOAT})
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
    elseif x.head == TUPLE || x.head == VCAT
        ret = Expr(Expr(x.head))
        for a in (x.args)
            if a isa EXPR && a.head == PARAMETERS
                unshift!(ret.args, Expr(a))
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

function remove_first_at!(x)
    if x isa EXPR && x.head isa OPERATOR{15, Tokens.DOT}
        return remove_first_at!(x.args[1])
    else
        return x.val = Symbol(string(x.val)[2:end])
    end
end


fixranges(a::INSTANCE) = Expr(a)
function fixranges(a::EXPR)
    if a.head isa HEAD{Tokens.CALL} && a.args[1] isa OPERATOR{6, Tokens.IN} || a.args[1] isa OPERATOR{6, Tokens.ELEMENT_OF}
        ret = Expr(:(=))
        for x in a.args[2:end]
            push!(ret.args, Expr(x))
        end
        return ret
    else
        return Expr(a)
    end
end


UNICODE_OPS_REVERSE = Dict{Tokenize.Tokens.Kind, Symbol}()
for (k, v) in Tokenize.Tokens.UNICODE_OPS
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
UNICODE_OPS_REVERSE[Tokens.ISSUPERTYPE] = :(>:)
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