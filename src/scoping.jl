function declares_function(x::Expression)
    if x isa EXPR
        if x.head isa KEYWORD{Tokens.FUNCTION}
            return true
        elseif x.head isa OPERATOR{1,Tokens.EQ} && x.args[1] isa EXPR && x.args[1].head==CALL
            return true
        else
            return false
        end
    else
        return false
    end
end

get_id{T<:INSTANCE}(x::T) = x

function get_id(x::EXPR)
    if x.head isa OPERATOR{6,Tokens.ISSUBTYPE} || x.head isa OPERATOR{14, Tokens.DECLARATION}
        return get_id(x.args[1])
    elseif x.head == CURLY
        return get_id(x.args[1])
    else
        return x
    end
end

get_t{T<:INSTANCE}(x::T) = :Any

function get_t(x::EXPR)
    if x.head isa OPERATOR{14, Tokens.DECLARATION}
        return x.args[2]
    else
        return :Any
    end
end