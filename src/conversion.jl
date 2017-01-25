import Base.Expr

Expr(x::IDENTIFIER) = x.val
Expr(x::LITERAL) = Base.parse(x.val)
Expr(x::OPERATOR) = Symbol(x.val)
Expr{T<:Expression}(x::Vector{T}) = Expr(:block, Expr.(x)...)
Expr(x::BLOCK) = Expr(:block, Expr.(x.args)...)
Expr(x::SYNTAXCALL) = Expr(Symbol(x.name.val), Expr.(x.args)...)
function Expr(x::COMPARISON)
    if length(x.args)==3
        if x.args[2] in ["<:", ">:"]
            return Expr(Expr(x.args[2]), Expr(x.args[1], Expr(x.args[3])))
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
Expr(x::RETURN) = Expr(:return, Expr(x.arg))
Expr(x::TYPEALIAS) = Expr(:typealias, Expr(x.name), Expr(x.body))
Expr(x::BITSTYPE) = Expr(:bitstype, Expr(x.bits), Expr(x.name))
Expr(x::TYPE) = Expr(:type, true, Expr(x.name), Expr(x.fields))
Expr(x::IMMUTABLE) = Expr(:type, false, Expr(x.name), Expr(x.fields))

Expr(x::CONST) = Expr(:const, Expr(x.decl))
Expr(x::GLOBAL) = Expr(:global, Expr(x.decl))
Expr(x::LOCAL) = Expr(:local, Expr(x.decl))


Expr(x::CURLY) = Expr(:curly, Expr(x.name), Expr.(x.args)...)