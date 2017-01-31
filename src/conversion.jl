import Base: Expr, Symbol

Expr(x::INSTANCE) = Symbol(x.val)
Expr(x::INSTANCE{LITERAL}) = Base.parse(x.val)
Expr(x::QUOTENODE) = QuoteNode(Expr(x.val))
Symbol(x::INSTANCE) = Symbol(x.val)
Expr(x::EXPR) = Expr(Symbol(x.head),Expr.(x.args)...)
