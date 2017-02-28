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
    if x.head isa OPERATOR{6,Tokens.ISSUBTYPE} || x.head isa OPERATOR{14, Tokens.DECLARATION} || x.head == CURLY
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

function func_sig(x::EXPR)
    name = x.args[1]
    args = x.args[2:end]
    if name isa EXPR && name.head == CURLY
        params = name.args[2]
        name = name.args[1]
    end
    if name isa EXPR && name.head isa OPERATOR{15,Tokens.DOT}
        mod = name.args[1]
        name = name.args[2]
    end
    if name isa QUOTENODE
        name = name.val
    end
end

function _track_assignment(ps::ParseState, x, val)
    if x isa IDENTIFIER
        push!(ps.current_scope.args, Variable(x, :Any, val))
    elseif x isa EXPR && x.head == TUPLE
        for a in x.args
            _track_assignment(ps, a, val)
        end
    end
end

function _get_full_scope(x::EXPR, n::Int)
    y, path, ind = find(x, n)
    full_scope = []
    for p in path
        if p isa EXPR && !(p.scope isa Scope{nothing})
            append!(full_scope, p.scope.args)
        end
    end
    full_scope
end

is_func_call(x) = false
function is_func_call(x::EXPR)
    x.head == CALL
end
