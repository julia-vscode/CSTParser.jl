function AbstractTrees.printnode(io::IO, x::EXPR{T}) where T
    print(io, T, "  ", x.fullspan, " (", x.span, ")")
    if isempty(x.defs)
        print(io)
    else
        print(io, "  {", join((a.id for a in x.defs), ","), "}")
    end
end
Base.show(io::IO, x::EXPR) = AbstractTrees.print_tree(io, x, 3)


function Base.show(io::IO, x::Scope{T}, indent = 0) where {T}
    print(io, "  "^indent, "↘ ", T, " (", length(x.args), ") ")
    println(io, "[", join(collect(a.id.val for a in x.args if a isa Variable), ", "), "]")
    for a in x.args
        if a isa Scope
            show(io, a, indent + 1)
        end
    end
end

function Base.show(io::IO, x::Variable, indent = 0)
    println(io, " "^indent, "Var → $(x.id)::$(x.t)")
end
