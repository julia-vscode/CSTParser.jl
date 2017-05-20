import Base: Expr
# Converts EXPR to Base.Expr
Expr(x::HEAD{T}) where {T} = Symbol(lowercase(string(T)))
Expr(x::HEAD{Tokens.LBRACE}) = :cell1d
Expr(x::KEYWORD{T}) where {T} = Symbol(lowercase(string(T)))

Expr(x::IDENTIFIER) = x.val
Expr(x::EXPR{IDENTIFIER}) = Symbol(x.val)

function Expr(x::EXPR{OPERATOR{O,K,dot}}) where {O, K, dot} 
    if dot
        Symbol(:., UNICODE_OPS_REVERSE[K])
    else
        UNICODE_OPS_REVERSE[K]
    end
end

Expr(x::LITERAL{Tokens.TRUE}) = true
Expr(x::LITERAL{Tokens.FALSE}) = false
Expr(x::ERROR) = "Parsing error"
Expr(x::LITERAL{T}) where {T} = Base.parse(x.val)
Expr(x::LITERAL{Tokens.FLOAT}) = Base.parse(x.val)
Expr(x::LITERAL{Tokens.MACRO}) = Symbol(x.val)
# Expr(x::LITERAL{Tokens.CMD}) = x.val
Expr(x::LITERAL{Tokens.STRING}) = x.val
Expr(x::LITERAL{Tokens.TRIPLE_STRING}) = x.val

Expr(x::PUNCTUATION{K}) where {K} = string(K)

Expr(x::EXPR{Quotenode}) = QuoteNode(Expr(x.args[1]))

function Expr(x::EXPR{Call})
    ret = Expr(:call)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Comparison})
    ret = Expr(:comparison)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{ChainOpCall})
    ret = Expr(:call, Expr(x.args[2]))
    for i = 1:length(x.args)
        if isodd(i)
            push!(ret.args, Expr(x.args[i]))
        end
    end
    ret
end

Expr(x::EXPR{BinaryOpCall}) = Expr(:call, Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))

Expr(x::EXPR{BinarySyntaxOpCall}) = Expr(Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))


Expr(x::EXPR{ConditionalOpCall}) = Expr(:if, Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))

Expr(x::EXPR{ColonOpCall}) = Expr(:(:), Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))

function Expr(x::EXPR{UnarySyntaxOpCall}) 
    if x.args[1] isa OPERATOR
        return Expr(Expr(x.args[1]), Expr(x.args[2]))
    else
        return Expr(Expr(x.args[2]), Expr(x.args[1]))
    end
end


# Expr(x::EXPR{FunctionDef}) = Expr(:function, Expr(x.args[2]), Expr(x.args[3]))
Expr(x::EXPR{Struct}) = Expr(:type, false, Expr(x.args[2]), Expr(x.args[3]))

Expr(x::EXPR{Mutable}) = length(x.args) == 4 ? Expr(:type, true, Expr(x.args[2]), Expr(x.args[3])) : Expr(:type, true, Expr(x.args[3]), Expr(x.args[4]))

Expr(x::EXPR{Abstract}) = length(x.args) == 2 ? Expr(:abstract, Expr(x.args[2])) : Expr(:abstract, Expr(x.args[3]))
Expr(x::EXPR{Bitstype}) = Expr(:bitstype, Expr(x.args[2]), Expr(x.args[3]))
Expr(x::EXPR{Primitive}) = Expr(:bitstype, Expr(x.args[4]), Expr(x.args[3]))
Expr(x::EXPR{TypeAlias}) = Expr(:typealias, Expr(x.args[2]), Expr(x.args[3]))


function Expr(x::EXPR{Block})
    ret = Expr(:block)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

function Expr(x::EXPR{TupleH})
    ret = Expr(:tuple)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

Expr(x::EXPR{Kw}) = Expr(:kw, Expr(x.args[1]), Expr(x.args[3]))

function Expr(x::EXPR{Parameters})
    ret = Expr(:parameters)
    for a in x.args
        push!(ret.args, Expr(a))
    end
    return ret
end

Expr(x::EXPR{InvisBrackets}) = Expr(x.args[2])
Expr(x::EXPR{Begin}) = Expr(x.args[2])
Expr(x::EXPR{Quote}) = Expr(:quote, Expr(x.args[2]))


function Expr(x::EXPR{If})
    ret = Expr(:if)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{FunctionDef})
    ret = Expr(:function)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Try})
    ret = Expr(:try)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Let})
    ret = Expr(:let, Expr(x.args[end-1]))
    for i = 1:length(x.args)-2
        a = x.args[i]
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Do})
    ret = Expr(x.args[1])
    insert!(ret.args, 2, Expr(:->, Expr(x.args[3]), Expr(x.args[4])))
    ret
end

function Expr(x::EXPR{For})
    ret = Expr(:for)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{While})
    ret = Expr(:while)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Return})
    ret = Expr(:return)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr(x::EXPR{Global})
    ret = Expr(:global)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr(x::EXPR{Local})
    ret = Expr(:local)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr(x::EXPR{Const})
    ret = Expr(:const)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end



function Expr(x::EXPR{Curly})
    ret = Expr(:curly)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Vect})
    ret = Expr(:vect)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{MacroCall})
    ret = Expr(:macrocall)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Row})
    ret = Expr(:row)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Hcat})
    ret = Expr(:hcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Vcat})
    ret = Expr(:vcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Ref})
    ret = Expr(:ref)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{TypedHcat})
    ret = Expr(:typed_hcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{TypedVcat})
    ret = Expr(:typed_vcat)
    
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Comprehension})
    ret = Expr(:comprehension)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Generator})
    ret = Expr(:generator, Expr(x.args[1]))
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa EXPR{BinaryOpCall} && a.args[2] isa OPERATOR{ComparisonOp, Tokens.IN}
                push!(ret.args, Expr(:(=), Expr(a.args[1]), Expr(a.args[3])))
            else
                push!(ret.args, Expr(a))
            end
        end
    end
    ret
end



function Expr(x::EXPR{TypedComprehension})
    ret = Expr(:typed_comprehension)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Export})
    ret = Expr(:export)
    for i = 2:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Import})
    ret = Expr(:import)
    for i = 2:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION) || (a isa PUNCTUATION{Tokens.DOT} && a.span>0)
            push!(ret.args, Expr(a))
        end
    end
    ret
end





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
        elseif x.args[1] isa EXPR && x.args[1].head isa OPERATOR{DotOp,Tokens.DOT} && string(x.args[1].args[2].val.val)[1] != '@'
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
        col = findfirst(x -> x isa OPERATOR{ColonOp,Tokens.COLON}, x.punctuation)
        ndots = 0
        while x.punctuation[ndots + 2] isa OPERATOR{DotOp,Tokens.DOT}
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
        # if x.head == CALL && x.args[1] isa OPERATOR{9, Tokens.MINUS} && length(x.args) == 2 && (x.args[2] isa LITERAL{Tokens.INTEGER} || x.args[2] isa LITERAL{Tokens.FLOAT})
        #     return -Expr(x.args[2])
        # end
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
    if x isa EXPR && x.head isa OPERATOR{DotOp,Tokens.DOT}
        return remove_first_at!(x.args[1])
    else
        return x.val = Symbol(string(x.val)[2:end])
    end
end


fixranges(a::INSTANCE) = Expr(a)
function fixranges(a::EXPR)
    if a.head isa HEAD{Tokens.CALL} && a.args[1] isa OPERATOR{ComparisonOp,Tokens.IN} || a.args[1] isa OPERATOR{ComparisonOp,Tokens.ELEMENT_OF}
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
UNICODE_OPS_REVERSE[Tokens.WHERE] = :where
