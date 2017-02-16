type Iterator{T}
    i::Int
    n::Int
end
+{T}(s::Iterator{T}) = (s.i+=1;s)

start(x::INSTANCE) = 1
next(x::INSTANCE, i) = x, i+1
length(x::INSTANCE) = 1
done(x::INSTANCE, i) = i>1


"""
    start(x::EXPR)

Creates an interator state for `EXPR`s. One can then iterator through all
 elements of an expression as they are ordered in the original code including 
punctuation.
"""
function start(x::EXPR)
    if x.head == CALL
        if x.args[1] isa INSTANCE{IDENTIFIER} || (x.args[1] isa EXPR && x.args[1].head == CURLY) # normal call
            return Iterator{:call}(1, length(x.args) + length(x.punctuation))
        elseif x.args[1] isa INSTANCE # op calls
            if x.args[1] isa INSTANCE{OPERATOR{9},Tokens.PLUS} || x.args[1] isa INSTANCE{OPERATOR{11},Tokens.STAR}
                return Iterator{:opchain}(1, max(2, length(x.args)*2-3))
            else
                return Iterator{:op}(1, length(x.args) + length(x.punctuation))
            end
        end
    elseif issyntaxcall(x.head)
        if x.head isa INSTANCE{OPERATOR{8},Tokens.COLON}
            return Iterator{:(:)}(1, length(x.args) == 2 ? 3 : 5)
        end
        return Iterator{:syntaxcall}(1, length(x.args) + 1)
    elseif x.head == COMPARISON
        return Iterator{:comparison}(1, length(x.args))
    elseif x.head == MACROCALL
        return _start_macrocall(x)
    elseif x.head isa INSTANCE{HEAD,Tokens.IF}
        return Iterator{:?}(1, 5)
    elseif x.head == BLOCK
        return Iterator{:block}(1, length(x.args) + length(x.punctuation))
    elseif x.head == GENERATOR
        return _start_generator(x)
    elseif x.head == TOPLEVEL
        @assert length(x.args) > 1
        if !(x.args[1] isa Expr && (x.args[1].head isa INSTANCE{KEYWORD, Tokens.IMPORT} || x.args[1].head isa INSTANCE{KEYWORD, Tokens.IMPORTALL} || x.args[1].head isa INSTANCE{KEYWORD, Tokens.USING})) 
            return Iterator{:toplevelblock}(1, length(x.args) + length(x.punctuation))
        else
            cnt = 1
            while x.args[1].args[cnt] == x.args[2].args[cnt]
                cnt+=1
            end
            return Iterator{:toplevel}(1, (cnt - 1 + length(x.args))*2)
        end
    elseif x.head == CURLY
        return _start_curly(x)
    elseif x.head == QUOTE
        return Iterator{:quote}(1, length(x.args) + length(x.punctuation))
    elseif x.head == REF
        return _start_ref(x)
    elseif x.head == TUPLE
        if first(x.punctuation) isa INSTANCE{PUNCTUATION,Tokens.LPAREN}
            return Iterator{:tuple}(1, length(x.args) + length(x.punctuation))
        else
            return Iterator{:tuplenoparen}(1, length(x.args) + length(x.punctuation))
        end
    elseif x.head isa INSTANCE{KEYWORD}
        if x.head isa INSTANCE{KEYWORD,Tokens.ABSTRACT} 
            return Iterator{:abstract}(1, 2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.BAREMODULE}
            return Iterator{:module}(1, 4)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.BEGIN}
            return Iterator{:begin}(1, 3)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.BITSTYPE}
            return Iterator{:bitstype}(1, 3)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.BREAK}
            return Iterator{:break}(1, 1)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.CONST}
            return Iterator{:const}(1, 2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.CONTINUE}
            return Iterator{:continue}(1, 1)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.DO}
        elseif x.head isa INSTANCE{KEYWORD,Tokens.EXPORT}
            return Iterator{:export}(1, length(x.args)*2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.FOR}
            return _start_for(x)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.FUNCTION}
            return _start_function(x)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.GLOBAL}
            return Iterator{:global}(1, 2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.IF}
            return _start_if(x)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.IMMUTABLE}
            return Iterator{:type}(1, 4)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.LOCAL}
            return Iterator{:local}(1, 2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.IMPORT} || 
               x.head isa INSTANCE{KEYWORD,Tokens.IMPORTALL} || 
               x.head isa INSTANCE{KEYWORD,Tokens.USING}
            return _start_imports(x)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.MACRO}
            return Iterator{:module}(1, 4)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.MODULE}
            return Iterator{:module}(1, 4)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.RETURN}
            return Iterator{:return}(1, 2)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.TRY}
            return _start_try(x)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.TYPE}
            return Iterator{:type}(1, 4)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.TYPEALIAS}
            return Iterator{:typealias}(1, 3)
        elseif x.head isa INSTANCE{KEYWORD,Tokens.WHILE}
            return _start_while(x)
        end
    end
end

done(x::EXPR, s::Iterator) = s.i > s.n
length(x::EXPR) = start(x).n

function Base.getindex(x::EXPR, i::Int)
    s = start(x)
    @assert i<=s.n
    s.i = i
    next(x, s)[1]
end

function Base.setindex!(x::EXPR, i::Int)
    s = start(x)
    @assert i<=s.n
    s.i = i
    next(x, s)[1]
end

function _find(x::EXPR, n, path, ind)
    offset = 0
    @assert n <= x.span
    push!(path, x)
    for (i, a) in enumerate(x)
        if n > offset + a.span
            offset += a.span
        else
            push!(ind, i)
            return _find(a, n-offset, path, ind)
        end
    end
end

_find(x::Union{QUOTENODE,INSTANCE}, n, path, ind) = x

function Base.find(x::EXPR, n)
    path = []
    ind = Int[]
    y = _find(x, n ,path, ind)
    return y, path, ind
end
