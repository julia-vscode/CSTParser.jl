
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

get_id(x::EXPR{Curly}) = get_id(x.args[1])
get_id(x) = x



"""
    get_t(x)

Basic inference in the presence of type declarations.
"""
get_t(x) = :Any
get_t(x::EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}}) = Expr(x.args[3])


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

"""
    _track_assignment(ps, x, val, defs = [])

When applied to the lhs of an assignment returns a vector of the 
newly defined variables.
"""
function _track_assignment(ps::ParseState, x, val, defs = [])
    if x isa EXPR{IDENTIFIER}
        t = infer_t(val)
        push!(defs, Variable(Expr(x), t, val))
    elseif x isa EXPR{TupleH}
        for a in x.args
            if a isa EXPR{IDENTIFIER}
                _track_assignment(ps, a, val, defs)
            end
        end
    end
    return defs
end

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

function get_symbols(x, offset = 0, symbols = []) end

function get_symbols(x::EXPR, offset = 0, symbols = [])
    for a in x.args
        for v in a.defs
            push!(symbols, (v, offset + (1:a.span)))
        end
        if contributes_scope(a)
            get_symbols(a, offset, symbols)
        end
        if a isa EXPR{ModuleH} || a isa EXPR{BareModule}
            m_scope = get_symbols(a.args[3])
            offset2 = offset + a.args[1].span + a.args[2].span
            for mv in m_scope
                push!(symbols, (Variable(Expr(:(.), a.defs[1].id, QuoteNode(mv[1].id)), mv[1].t, mv[1].val), mv[2] + offset2))
            end
        end
        offset += a.span
    end
    return symbols
end

"""
    contributes_scope(x)
Checks whether the body of `x` is included in the toplevel namespace.
"""
contributes_scope(x) = false
contributes_scope(x::EXPR{Begin}) = true
contributes_scope(x::EXPR{Block}) = true
contributes_scope(x::EXPR{Const}) = true
contributes_scope(x::EXPR{Global}) = true
contributes_scope(x::EXPR{Local}) = true
contributes_scope(x::EXPR{If}) = true
contributes_scope(x::EXPR{MacroCall}) = true
