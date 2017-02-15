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

function next(x::EXPR, s::Iterator{:call})
    if  s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:opchain})
    if isodd(s.i)
        return x.args[div(s.i+1,2)+1], +s
    elseif s.i == 2
        return x.args[1], +s
    else 
        return x.punctuation[div(s.i, 2)-1], +s
    end
end


function next(x::EXPR, s::Iterator{:op})
    if length(x.args) == 2
        if s.i==1
            return x.args[1], +s
        elseif s.i==2
            return x.args[2], +s
        end
    else
        if s.i==1
            return x.args[2], +s
        elseif s.i==2
            return x.args[1], +s
        elseif s.i==3 
            return x.args[3], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:(:)})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return x.head, +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    elseif s.i == 5 
        return x.args[3], +s
    end
end

function next(x::EXPR, s::Iterator{:syntaxcall})
    if s.i==1
        return x.args[1], +s
    elseif s.i==2
        return x.head, +s
    elseif s.i==3 
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:?})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2 
        return x.punctuation[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4 
        return x.punctuation[2], +s
    elseif s.i == 5
        return x.args[3], +s
    end 
end

function next(x::EXPR, s::Iterator{:comparison})
    return x.args[s.i], +s
end

function next(x::EXPR, s::Iterator{:tuple})
    if isodd(s.i)
        return x.punctuation[div(s.i+1, 2)], +s
    elseif s.i==s.n
        return last(x.punctuation), +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:tuplenoparen})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:block})
    if length(x.punctuation)==2
        if s.i == 1
            return x.punctuation[1], +s
        elseif s.i == s.n
            return x.punctuation[2], +s
        else
            return x.args[s.i-1], +s
        end
    end

    return x.args[s.i], +s
end




# KEYWORDS



function next(x::EXPR, s::Iterator{:begin})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.punctuation[1], +s
    end
end




function next(x::EXPR, s::Iterator{:toplevel})
    if s.i == 1
        return x.args[1].head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        if s.i <= div(s.n, 2)
            return x.args[1].args[div(s.i, 2)], +s
        else
            # this needs to be fixed for `import A: a, b.c`
            return last(x.args[div(s.i-div(s.n, 2)+1, 2)].args), +s
        end
    end
end





function next(x::EXPR, s::Iterator{:quote})
    if s.i == 1
        return x.punctuation[1], +s
    elseif s.i == s.n
        return x.punctuation[end], +s
    elseif s.i == 2
        if s.n == 4
            return x.punctuation[2], +s
        else
            return x.args[1], +s
        end
    elseif s.i == 3
        return x.args[1], +s
    end
end



function Base.find(x::EXPR, n)
    i = 0
    @assert n <= x.span
    for a in x
        if n > i+a.span
            i+=a.span
        else
            return find(a, n-i)
        end
    end
end

function Base.find(x::Union{QUOTENODE,INSTANCE}, n)
    return x
end



function next(x::EXPR, s::Iterator{:toplevelblock})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end