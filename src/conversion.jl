import Base.Expr

Expr(x::INSTANCE{IDENTIFIER}) = Symbol(x.val)
Expr(x::INSTANCE{LITERAL}) = Base.parse(x.val)
Expr(x::OPERATOR) = Symbol(x.val)
Expr{T<:Expression}(x::Vector{T}) = Expr(:block, Expr.(x)...)
Expr(x::BLOCK) = Expr(:block, Expr.(x.args)...)
Expr(x::SYNTAXCALL) = Expr(Symbol(x.name.val), Expr.(x.args)...)
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
    if x.name.val in ["||", "&&", "::"]
        return Expr(Symbol(x.name.val), Expr.(x.args)...)
    end

    return Expr(:call, Expr(x.name), Expr.(x.args)...)
end

function Expr(x::FUNCTION) 
    if x.oneliner
        return Expr(:(=), Expr(x.signature), Expr(x.body))
    elseif isempty(x.body.args)
        return Expr(:function, Expr(x.signature))
    else
        return Expr(:function, Expr(x.signature), Expr(x.body))
    end
end


Expr(x::CURLY) = Expr(:curly, Expr(x.name), Expr.(x.args)...)



Expr(x::KEYWORD_BLOCK{1}) = Expr(Symbol(x.opener.val), Expr(x.args[1]))    
Expr(x::KEYWORD_BLOCK{2}) = Expr(Symbol(x.opener.val), Expr.(x.args)...)
function Expr(x::KEYWORD_BLOCK{3})
    if x.opener.val in ["type", "module"]
        return Expr(Symbol(x.opener.val), true, Expr(x.args[1]), Expr(x.args[2]))
    elseif x.opener.val in ["immutable", "baremodule"]
        return Expr(Symbol(x.opener.val), false, Expr(x.args[1]), Expr(x.args[2]))
    else
        return Expr(Symbol(x.opener.val), Expr(x.args[1]), Expr(x.args[2]))
    end
end