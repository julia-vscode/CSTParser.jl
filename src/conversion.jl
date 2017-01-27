import Base.Expr

Expr(x::INSTANCE{IDENTIFIER}) = Symbol(x.val)
Expr(x::INSTANCE{LITERAL}) = Base.parse(x.val)
Expr(x::OPERATOR) = Symbol(x.val)
Expr{T<:Expression}(x::Vector{T}) = Expr(:block, Expr.(x)...)
Expr(x::BLOCK) = Expr(:block, Expr.(x.args)...)

function Expr(x::COMPARISON)
    if length(x.args)==3
        if x.args[2].val in ["<:", ">:"]
            return Expr(Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
        else
            return Expr(:call, Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
        end
    else
        return Expr(:comparison, Expr.(x.args)...)
    end
end

function Expr(x::CALL)
    if x.name isa OPERATOR && x.name.precedence == 1
        return Expr(Symbol(x.name.val), Expr.(x.args)...)
    elseif x.name isa OPERATOR && x.name.val in ["||", "&&", "::"]
        return Expr(Symbol(x.name.val), Expr.(x.args)...)
    elseif x.name isa OPERATOR && x.name.val == ":"
        return Expr(:(:), Expr.(x.args)...)
    elseif x.name isa OPERATOR && x.name.val == "."
        if x.args[2] isa INSTANCE{IDENTIFIER}
            return Expr(:(.), Expr(x.args[1]), QuoteNode(Expr(x.args[2])))
        else
            return Expr(:(.), Expr(x.args[1]), Expr(x.args[2]))
        end
    else
        return Expr(:call, Expr(x.name), Expr.(x.args)...)
    end
end

Expr(x::CURLY) = Expr(:curly, Expr(x.name), Expr.(x.args)...)

Expr(x::KEYWORD_BLOCK{0}) = Symbol(x.opener.val)

Expr(x::KEYWORD_BLOCK{1}) = Expr(Symbol(x.opener.val), Expr(x.args[1]))    

Expr(x::KEYWORD_BLOCK{2}) = Expr(Symbol(x.opener.val), Expr.(x.args)...)

function Expr(x::KEYWORD_BLOCK{3})
    if x.opener.val in ["type", "module"]
        return Expr(Symbol(x.opener.val), true, Expr(x.args[1]), Expr(x.args[2]))
    elseif x.opener.val == "immutable"
        return Expr(:immutable, false, Expr(x.args[1]), Expr(x.args[2]))
    elseif x.opener.val == "baremodule"
        return Expr(:module, false, Expr(x.args[1]), Expr(x.args[2]))
    elseif x.opener.val=="function"
        if x.opener.span==0
            return Expr(:(=), Expr(x.args[1]), Expr(x.args[2]))
        else
            return Expr(Symbol(x.opener.val), Expr(x.args[1]), Expr(x.args[2]))
        end
    elseif x.opener.val == "begin"
        return Expr(x.args[1])
    else
        return Expr(Symbol(x.opener.val), Expr(x.args[1]), Expr(x.args[2]))
    end
end