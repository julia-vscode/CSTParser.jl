# """
#     span(x)

# Returns the number of bytes between the first and last character of 
# the expression.
# """
# function span end
# """
#     span(x)

# Returns the number of bytes between the first character of the 
# expression and the last character of any whitespace trailing behind 
# the last character of the expression.
# """
# function spanws end




start(x::INSTANCE) = 1
next(x::INSTANCE, i) = x, i+1
length(x::INSTANCE) = 1
done(x::INSTANCE, i) = i>1

start(x::EXPR) = 1

function next(x::EXPR, i)
    if x.head==COMPARISON
        return x.args[i], i+1
    elseif x.head==CALL
        return _next_call(x, i)
    elseif x.head.val == "module" || x.head.val == "type" || x.head.val == "while" || x.head.val == "function"
        return _next_function(x, i)
    elseif x.head.val == "block"
        return x.args[i], i+1
    elseif x.head.val == "const" || x.head.val == "abstract" 
        return _next_const_abstract(x, i)
    elseif x.head.val == "typealias" || x.head.val == "bitstype" 
        return _next_bitstype_typealias(x, i)
    elseif x.head.val == "curly"
        return _next_curly(x, i)
    elseif x.head.val == "if" && x.head.span==0
        return _next_ifop(x, i)
    elseif issyntaxcall(x.head.val)
        return _next_syntaxcall(x, i)
    end
end

function length(x::EXPR)
    if x.head==COMPARISON
        return length(x.args)
    elseif x.head == CALL
        if x.args[1] isa INSTANCE{IDENTIFIER} || (x.args[1].head.val == "curly")
            return length(x.args)*2
        elseif x.args[1] isa INSTANCE
            if x.args[1].val=="+" || x.args[1].val=="*"
                return max(2, length(x.args)*2-3)
            end
        end
        return length(x.args) + length(x.punctuation)
    elseif issyntaxcall(x.head.val)
        if x.head.val ==":"
            return length(x.args) == 2 ? 3 : 5
        end
        return length(x.args)+1
    elseif x.head.val == "abstract" || x.head.val == "local" || x.head.val == "global" || x.head.val == "return" || x.head.val == "const"
        return 2
    elseif x.head.val == "export"
        return length(x.args)*2
    elseif x.head.val == "bitstype" || x.head.val == "typealias" 
        return 3
    elseif x.head.val == "block"
        return length(x.args)
    elseif x.head.val == "module" || x.head.val == "type" || x.head.val == "while" || x.head.val == "function" || x.head.val == "macro" || x.head.val == "for"
        return 4
    elseif x.head.val == "import" || x.head.val == "importall" || x.head.val == "using"
    elseif x.head.val == "if"
        if x.head.span==0
            return 5
        else
            return 2 + length(x.args)
        end
    elseif x.head.val == "try"
        if isempty(x.args[3].args)
            return 3
        else
            return 6
        end
    elseif x.head.val == "curly"
        return length(x.args)*2
    elseif x.head.val == "tuple"
        return length(x.args) + length(x.punctuation)
    end
end

done(x::EXPR, i) = i>length(x)

type Iterator{T}
    i::Int
    n::Int
end





function _next_module(x::EXPR, i)
    if i == 1
        return x.head, 2
    elseif i == 2
        return x.args[2], 3
    elseif i == 3
        return x.args[3], 4
    elseif i ==4
        return x.punctuation[1], 5
    end
end

function _next_function(x::EXPR, i)
    if i == 1
        return x.head, 2
    elseif i == 2
        return x.args[1], 3
    elseif i == 3
        return x.args[2], 4
    elseif i ==4
        return x.punctuation[1], 5
    end
end

function _next_bitstype_typealias(x::EXPR, i)
    if i == 1
        return x.head, 2
    elseif i == 2
        return x.args[1], 3
    elseif i == 3
        return x.args[2], 4
    end
end

function _next_const_abstract(x::EXPR, i)
    if i == 1
        return x.head, 2
    elseif i == 2
        return x.args[1], 3
    end
end



function _next_syntaxcall(x::EXPR, i)
    if x.head.val == ":"
        if i == 1
            return x.args[1], 2
        elseif i == 2
            return x.head, 3
        elseif i == 3
            return x.args[2], 4
        elseif i == 4
            return x.punctuation[1], 5
        elseif i == 5 
            return x.args[3], 6
        end
    else
        if i==1
            return x.args[1], 2
        elseif i==2
            return x.head, 3
        elseif i==3 
            return x.args[2], 4
        end
    end
end

function _next_curly(x::EXPR, i)
    if i==1
        return x.args[1], 2
    elseif i==2
        return x.punctuation[1], 3
    elseif i==length(x) 
        return last(x.punctuation), i+1
    elseif isodd(i)
        return x.args[div(i+1, 2)], i+1
    else
        return x.punctuation[div(i, 2)], i+1
    end
end


function _next_call(x::EXPR, i)
    if x.args[1] isa INSTANCE{IDENTIFIER} || (x.args[1].head.val == "curly")
        if isodd(i)
            return x.args[div(i+1, 2)], i+1
        else
            return x.punctuation[div(i, 2)], i+1
        end
    elseif x.args[1] isa INSTANCE
        if x.args[1].val=="+" || x.args[1].val=="*"
            if isodd(i)
                return x.args[div(i+1,2)+1], i+1
            else
                return x.args[1], i+1
            end
        end
        if i==1
            return x.args[2], 2
        elseif i==2
            return x.args[1], 3
        elseif i==3 
            return x.args[3], 4
        end
    else
        return x.args[i], i+1
    end
end

function _next_ifop(x::EXPR, i)
    if i == 1
        return x.args[1], 2
    elseif i == 2 
        return x.punctuation[1], 3
    elseif i == 3
        return x.args[2], 4
    elseif i == 4 
        return x.punctuation[2], 5
    elseif i == 5
        return x.args[3], 6
    end 
end