function Base.show(io::IO, x::EXPR{T}, indent = 0) where T
    indent == 3 && return
    name = sprint(show, T)
    print(io, "  "^indent, T, "  ", x.span)
    if isempty(x.defs)
        println()
    else
        println("  {", join((a.id for a in x.defs), ","), "}")
    end
    for (i, a) in enumerate(x.args)
        show(io, a, indent + 1)
    end 
end


function Base.show(io::IO, x::Scope{T}, indent = 0) where {T}
    print(io, "  "^indent, "↘ ", T, " (", length(x.args), ") ")
    println("[", join(collect(a.id.val for a in x.args if a isa Variable), ", "), "]")
    for a in x.args
        if a isa Scope
            show(io, a, indent + 1)
        end
    end 
end

function Base.show(io::IO, x::Variable, indent = 0)
    println(io, " "^indent, "Var → $(x.id)::$(x.t)")
end
