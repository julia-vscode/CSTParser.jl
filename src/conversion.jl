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
function Expr(x::EXPR)
    if x.head==BLOCK && length(x.punctuation)==2
        return Expr(x.args[1])
    elseif x.head isa INSTANCE{KEYWORD,Tokens.BEGIN}
        return Expr(x.args[1])
    elseif x.head.val == "generator"
        return Expr(:generator, Expr(x.args[1]), fixranges.(x.args[2:end])...)
    elseif x.head == MACROCALL
        return Expr(:macrocall, Symbol("@$(x.args[1].val)"), Expr.(x.args[2:end])...)
    end
    return Expr(Symbol(x.head), Expr.(x.args)...)
end


function fixranges(a::EXPR)
    if a.head==CALL && a.args[1].val == "in" || a.args[1].val == "∈"
        return Expr(:(=), Expr.(a.args[2:end])...)
    else
        return Expr(a)
    end
end
