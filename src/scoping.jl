
"""
    get_id(x)

Get the IDENTIFIER name of a variable, possibly in the presence of 
type declaration operators.
"""

function get_id(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}} || x.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        return get_id(x.args[1])
    else
        return x
    end
end

function get_id(x::EXPR{UnarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{DddotOp,Tokens.DDDOT,false}}
        return get_id(x.args[1])
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
function get_t(x::EXPR{BinarySyntaxOpCall}) 
    if x.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}}
        return Expr(x.args[3])
    else
        return :Any
    end
end

# NEEDS FIX
# function func_sig(x::EXPR)
#     name = x.args[1]
#     args = x.args[2:end]
#     if name isa EXPR && name.head == CURLY
#         params = name.args[2]
#         name = name.args[1]
#     end
#     if name isa EXPR && name.head isa OPERATOR{DotOp,Tokens.DOT}
#         mod = name.args[1]
#         name = name.args[2]
#     end
#     if name isa EXPR{Quotenode}
#         name = name.val
#     end
# end


infer_t(x) = :Any
infer_t(x::EXPR{LITERAL{Tokens.INTEGER}}) = :Int
infer_t(x::EXPR{LITERAL{Tokens.FLOAT}}) = :Float64
infer_t(x::EXPR{LITERAL{Tokens.STRING}}) = :String
infer_t(x::EXPR{LITERAL{Tokens.TRIPLE_STRING}}) = :String
infer_t(x::EXPR{LITERAL{Tokens.CHAR}}) = :Char
infer_t(x::EXPR{LITERAL{Tokens.TRUE}}) = :Bool
infer_t(x::EXPR{LITERAL{Tokens.FALSE}}) = :Bool
infer_t(x::EXPR{LITERAL{Tokens.CMD}}) = :Cmd

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
