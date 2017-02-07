import Base: Expr, Symbol

Expr(x::INSTANCE) = Symbol(x.val)
Expr(x::INSTANCE{LITERAL}) = Base.parse(x.val)
Expr(x::QUOTENODE) = QuoteNode(Expr(x.val))
function Symbol(x::INSTANCE)
    if x==NOTHING
        return nothing
    end
    return Symbol(x.val)
end
Expr(x::EXPR) = Expr(Symbol(x.head),Expr.(x.args)...)
