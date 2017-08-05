function AbstractTrees.printnode(io::IO, x::EXPR{T}) where T
    print(io, T, "  ", x.fullspan, " (", x.span, ")")
    print(io)
end
Base.show(io::IO, x::EXPR) = AbstractTrees.print_tree(io, x, 3)

