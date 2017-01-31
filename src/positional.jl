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


span{T<:Expression}(x::T) = x.loc.stop-x.loc.start


start(x::INSTANCE) = x
next(x::INSTANCE) = x
length(x::INSTANCE) = 1
done(x::INSTANCE) = x

start(x::EXPR) = 1

function next(x::EXPR, i)
    if x.head==COMPARISON
        return x.args[i], i+1
    elseif x.head==CALL
        if x.args[1] isa INSTANCE && 1<=(x.args[1].prec)<=15
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
    elseif (x.head isa INSTANCE && 
        x.head.prec==1 ||
        x.head.prec==4 ||
        x.head.prec==5 ||
        x.head.val=="<:" ||
        x.head.val==">:" ||
        x.head.val=="-->" ||
        x.head.prec==8 ||
        x.head.prec==14 ||
        x.head.prec==15)
        if i==1
            return x.args[1], 2
        elseif i==2
            return x.head, 3
        elseif i==3 
            return x.args[2], 4
        end
    end
end

function length(x::EXPR)
    if x.head==COMPARISON
        return length(x.args)
    elseif x.head==CALL
        if x.args[1] isa INSTANCE && 1<=(x.args[1].prec)<=15
            if x.args[1].val=="+" || x.args[1].val=="*"
                return length(x.args)*2-3
            end
        end
        return length(x.args)
    elseif (x.head isa INSTANCE && 
        x.head.prec==1 ||
        x.head.prec==4 ||
        x.head.prec==5 ||
        x.head.val=="<:" ||
        x.head.val==">:" ||
        x.head.val=="-->" ||
        x.head.prec==8 ||
        x.head.prec==14 ||
        x.head.prec==15)
        return length(x.args)+1
    end
end

done(x::EXPR, i) = i>length(x)



function first(x::EXPR)
    if x.head==CALL
        if x.args[1] isa INSTANCE && 1 <=x.args[1].prec <=15 && length(x.args)>2
            return x.args[2]
        else
            return x.args[1]
        end
    elseif x.head==COMPARISON || 
        (x.head isa INSTANCE && 
        x.head.prec==1 ||
        x.head.prec==4 ||
        x.head.prec==5 ||
        x.head.val=="<:" ||
        x.head.val==">:" ||
        x.head.prec==8 ||
        x.head.prec==14 ||
        x.head.prec==15)
        return x.args[1]
    end
end

function last(x::EXPR)
    if x.head==COMPARISON || 
        x.head == CALL || (x.head isa INSTANCE && 
        x.head.prec==1 ||
        x.head.prec==4 ||
        x.head.prec==5 ||
        x.head.val=="<:" ||
        x.head.val==">:" ||
        x.head.prec==8 ||
        x.head.prec==14 ||
        x.head.prec==15)
        return last(x.args)
    end
end
