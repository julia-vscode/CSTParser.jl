"""
    get_id(x)

Get the IDENTIFIER name of a variable, possibly in the presence of 
type declaration operators.
"""
function get_id(x::BinarySyntaxOpCall)
    if is_issubt(x.op) || is_decl(x.op)
        return get_id(x.arg1)
    else
        return x
    end
end

function get_id(x::WhereOpCall)
    return get_id(x.arg1)
end

function get_id(x::UnarySyntaxOpCall)
    if is_dddot(x.arg2)
        return get_id(x.arg1)
    else
        return x
    end
end

get_id(x::EXPR{Curly}) = get_id(x.args[1])
get_id(x) = x



"""
    get_t(x)

Basic inference in the presence of type declarations.
"""
get_t(x) = :Any
function get_t(x::BinarySyntaxOpCall) 
    if is_decl(x.op)
        return Expr(x.arg2)
    else
        return :Any
    end
end


infer_t(x) = :Any
function infer_t(x::LITERAL)
    if x.kind == Tokens.INTEGER
        return :Int
    elseif x.kind == Tokens.FLOAT
        return :Float64
    elseif x.kind == Tokens.STRING
        return :String
    elseif x.kind == Tokens.TRIPLE_STRING
        return :String
    elseif x.kind == Tokens.CHAR
        return :Char
    elseif x.kind == Tokens.TRUE || x.kind == Tokens.FALSE
        return :Bool
    elseif x.kind == Tokens.CMD
        return :Cmd
    end
end

infer_t(x::EXPR{Vect}) = :(Array{Any,1})
infer_t(x::EXPR{Vcat}) = :(Array{Any,N})
infer_t(x::EXPR{TypedVcat}) = :(Array{$(Expr(x.args[1])),N})
infer_t(x::EXPR{Hcat}) = :(Array{Any,2})
infer_t(x::EXPR{TypedHcat}) = :(Array{$(Expr(x.args[1])),2})
infer_t(x::EXPR{Quote}) = :Expr
infer_t(x::EXPR{StringH}) = :String
infer_t(x::EXPR{Quotenode}) = :QuoteNode


"""
    contributes_scope(x)
Checks whether the body of `x` is included in the toplevel namespace.
"""
contributes_scope(x) = false
contributes_scope(x::EXPR{FileH}) = true
contributes_scope(x::EXPR{Begin}) = true
contributes_scope(x::EXPR{Block}) = true
contributes_scope(x::EXPR{Const}) = true
contributes_scope(x::EXPR{Global}) = true
contributes_scope(x::EXPR{Local}) = true
contributes_scope(x::EXPR{If}) = true
contributes_scope(x::EXPR{MacroCall}) = true
contributes_scope(x::EXPR{TopLevel}) = true
