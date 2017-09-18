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

function get_id(x::EXPR)
    if x.head == Curly
        return get_id(x.args[1])
    elseif x.head == InvisBrackets
        return get_id(x.args[2])
    else
        return x
    end
end

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

function infer_t(x::EXPR)
    x.head == Vect && return :(Array{Any,1})
    x.head == Vcat && return :(Array{Any,N})
    x.head == TypedVcat && return :(Array{$(Expr(x.args[1])),N})
    x.head == Hcat && return :(Array{Any,2})
    x.head == TypedHcat && return :(Array{$(Expr(x.args[1])),2})
    x.head == Quote && return :Expr
    x.head == StringH && return :String
    x.head == Quotenode && return :QuoteNode
    error("unknowd head, got $(x.head)")
end

"""
    contributes_scope(x)
Checks whether the body of `x` is included in the toplevel namespace.
"""
contributes_scope(x) = false
function contributes_scope(x::EXPR)
    x.head == FileH && return true
    x.head == Begin && return true
    x.head == Block && return true
    x.head == Const && return true
    x.head == Global && return true
    x.head == Local && return true
    x.head == If && return true
    x.head == MacroCall && return true
    x.head == TopLevel && return true
    return false
end
