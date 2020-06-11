module Iterating
using ..CSTParser: EXPR, headof, hastrivia, isoperator, valof

function Base.getindex(x::EXPR, i)
    if headof(x) === :const
        _const(x, i)
    elseif headof(x) === :local || headof(x) === :return
        oddt_evena(x, i)
    elseif headof(x) === :global
        _global(x, i)
    elseif headof(x) === :abstract
        _abstract(x, i)
    elseif headof(x) === :primitive
        _primitive(x, i)
    elseif headof(x) === :struct
        _struct(x, i)
    elseif headof(x) === :block
        _block(x, i)
    elseif headof(x) === :quote
        _quote(x, i)
    elseif headof(x) === :quotenode
        _quotenode(x, i)
    elseif headof(x) === :for
        taat(x, i)
    elseif headof(x) === :if
        _if(x, i)
    elseif headof(x) === :elseif
        _elseif(x, i)
    elseif headof(x) === :function
        _function(x, i)
    elseif headof(x) === :outer
        ta(x, i)
    elseif headof(x) === :tuple
        _tuple(x, i)
    elseif headof(x) === :braces
        _braces(x, i)
    elseif headof(x) === :curly
        _curly(x, i)
    elseif headof(x) === :call
        _call(x, i)
    elseif headof(x) === :kw
        _kw(x, i)
    elseif headof(x) === :comparison || headof(x) === :file
        x.args[i]
    elseif headof(x) === :using
        _using(x, i)
    elseif isoperator(headof(x))
        if valof(headof(x)) == ":"
            _colon_in_using(x, i)
        elseif valof(headof(x)) == "."
            _dot(x, i)
        elseif !hastrivia(x)
            if i == 1
                x.args[1]
            elseif i == 2
                x.head
            elseif i == 3
                x.args[2]
            end
        end
    elseif headof(x) === :string
        _string(x, i)
    elseif headof(x) === :vect
        oddt_evena(x, i)
    end
end
Base.iterate(x::EXPR) = length(x) == 0 ? nothing : (x[1], 1)
Base.iterate(x::EXPR, s) = s < length(x) ? (x[s + 1], s + 1) : nothing
Base.firstindex(x::EXPR) = 1
Base.lastindex(x::EXPR) = x.args === nothing ? 0 : length(x)

# Base.setindex!(x::EXPR, val, i) = Base.setindex!(x.args, val, i)
# Base.first(x::EXPR) = x.args === nothing ? nothing : first(x.args)
# Base.last(x::EXPR) = x.args === nothing ? nothing : last(x.args)


function ta(x, i)
    if i == 1
        x.trivia[1]
    elseif i == 2
        x.args[1]
    end
end
function tat(x, i)
    if i == 1
        x.trivia[1]
    elseif i == 2
        x.args[1]
    elseif i == 3
        x.trivia[2]
    end
end

function taat(x, i)
    if i == 1
        x.trivia[1]
    elseif i == 2
        x.args[1]
    elseif i == 3
        x.args[2]
    elseif i == 4
        x.trivia[2]
    end
end


function oddt_evena(x, i)
    if isodd(i)
        x.trivia[div(i + 1, 2)]
    else
        x.args[div(i, 2)]
    end
end

function odda_event(x, i)
    if isodd(i)
        x.args[div(i + 1, 2)]
    else
        x.trivia[div(i, 2)]
    end
end


function _const(x, i) 
    if length(x.trivia) === 1
        ta(x, i)
    elseif length(x.trivia) === 2
        #global const
        if i < 3
            x.trivia[i]
        elseif i == 3
            x.args[1]
        end
    end
end

function _global(x, i) 
    if hastrivia(x) && headof(first(x.trivia)) === :global
        oddt_evena(x, i)
    else
        odda_event(x, i)
    end
end

function _abstract(x, i)
    if i < 3
        x.trivia[i]
    elseif i == 3
        x.args[1]
    elseif i == 4
        x.trivia[3]
    end
end

function _primitive(x, i)
    if i < 3
        x.trivia[i]
    elseif i == 3
        x.args[1]
    elseif i == 4
        x.args[2]
    elseif i == 5
        x.trivia[3]
    end
end

function _struct(x, i)
    if length(x.trivia) == 2
        if i == 1
            x.trivia[1]
        elseif 1 < i < 5
            x.args[i - 1]
        elseif i == 5
            x.trivia[2]
        end
    elseif length(x.trivia) == 3 # mutable
        if i < 3
            x.trivia[i]
        elseif 2 < i < 6
            x.args[i - 2]
        elseif i == 6
            x.trivia[3]
        end
    end
end

function _block(x, i)
    if hastrivia(x) # We have a begin block
        if i == 1
            x.trivia[1]
        elseif 1 < i < length(x)
            x.args[i - 1]
        elseif i == length(x)
            x.trivia[2]
        end
    else
        x.args[i]
    end
end

function _quote(x, i)
    if length(x.trivia) == 1
        if i == 1
            x.trivia[1]
        elseif i == 2
            x.args[1]
        end
    else length(x.trivia) == 2
        tat(x, i)
    end
end

function _quotenode(x, i)
    if hastrivia(x)
        if i == 1
            x.trivia[1]
        elseif i == 2
            x.args[1]
        end
    elseif i == 1
        x.args[1]
    end
end

function _function(x, i)
    if length(x.args) == 1
        tat(x, i)
    else length(x.args) == 2
        taat(x, i)
    end
end

function _braces(x, i)
    if length(x.args) > 0 && headof(x.args[1]) === :parameters
        if i == 1 
            x.trivia[1]
        elseif i == length(x)
            last(x.trivia)
        elseif i == length(x) - 1
            x.args[1]
        elseif iseven(i)
            x.args[div(i, 2) + 1]
        else
            x.trivia[div(i + 1, 2)]
        end
    else
        if i == length(x)
            last(x.trivia)
        else
            oddt_evena(x, i)
        end
    end
end

function _curly(x, i)
    if i == 1
        x.args[1]
    elseif i == length(x)
        last(x.trivia)
    elseif length(x.args) > 1 && headof(x.args[2]) === :parameters
        if i == length(x) - 1
            x.args[2]
        elseif isodd(i)
            x.args[div(i + 1, 2) + 1]
        else
            x.trivia[div(i, 2)]
        end
    else
        if isodd(i)
            x.args[div(i + 1, 2)]
        else
            x.trivia[div(i, 2)]
        end
    end
end

function _using(x, i)
    oddt_evena(x, i)
end

function _colon_in_using(x, i)
    if i == 1
        x.args[1]
    elseif i == 2
        x.head
    elseif isodd(i)
        x.args[div(i + 1, 2)]
    else
        x.trivia[div(i, 2)]
    end
end

function _dot(x, i)
    if x.head.span == 0 # Empty dot op, in using statement
        if i == 1
            x.head
        elseif iseven(i)
            x.args[div(i, 2)]
        else
            x.trivia[div(i + 1, 2) - 1]
        end
    else
        if i == 1
            x.args[1]
        elseif i == 2
            x.head
        elseif i == 3
            x.args[2]
        end
    end
end

function _call(x, i)
    if hastrivia(x)
        _curly(x, i)
    elseif isoperator(x.args[1])
        if i == 1
            x.args[2]
        elseif i == 2
            x.args[1]
        elseif i == 3
            x.args[3]
        end
    end
end

function _kw(x, i)
    if i == 1
        x.args[1]
    elseif i == 2
        x.trivia[1]
    elseif i == 3
        x.args[2]
    end
end

function _tuple(x, i)
    hasparams = headof(x.args[1]) === :parameters
    if hasparams
        if i == length(x)
            last(x.trivia)
        elseif i == last(x) - 1
            first(x.args)

        end
    else
        if length(x.trivia) == length(x.args) - 1  # No brackets, no trailing comma
            odda_event(x, i)
        elseif length(x.trivia) - 1 == length(x.args) # Brackets, no trailing comma
            oddt_evena(x, i)
        elseif length(x.trivia) - 2 == length(x.args) # Brackets, trailing comma
            if i == length(x)
                last(x.trivia)
            elseif i == length(x) - 1
                x.trivia[end-1]
            else
                oddt_evena(x, i)
            end

        end
    end
end

function _if(x, i)
    if length(x) == 4 # if c expr end
        taat(x, i)
    elseif length(x) == 5 # if c expr elseif... end
    if i == 1
        x.trivia[1]
    elseif i == 2
        x.args[1]
    elseif i == 3
        x.args[2]
    elseif i == 4
        x.args[3]
    elseif i == 5
        x.trivia[2]
    end
    elseif length(x) == 6 # if c expr else expr end
        if i == 1
            x.trivia[1]
        elseif i == 2
            x.args[1]
        elseif i == 3
            x.args[2]
        elseif i == 4
            x.trivia[2]
        elseif i == 5
            x.args[3]
        elseif i == 6
            x.trivia[3]
        end
    end
end

function _elseif(x, i)
    if length(x) == 3 || length(x) == 5
        if i == 1
            x.trivia[1]
        elseif i == 2
            x.args[1]
        elseif i == 3
            x.args[2]
        elseif i == 4
            x.trivia[2]
        elseif i == 5
            x.args[3]
        end
    end
end

function _string(x, i)
    if i == length(x)
        last(x.args)
    else
        n, r = divrem(i, 3)
        if r == 1
            x.args[i]
        elseif r == 2
            x.trivia[n + 1]
        elseif r == 0
            x.args[(n)*3 - 1]
        end
    end
end

end
