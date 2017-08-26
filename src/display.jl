function AbstractTrees.printnode(io::IO, x::EXPR{T}) where T
    print(io, T, "  ", x.fullspan, " (", x.span, ")")
    print(io)
end
Base.show(io::IO, x::EXPR) = AbstractTrees.print_tree(io, x, 3)

function AbstractTrees.printnode(io::IO, x::T) where T <: Union{BinaryOpCall,BinarySyntaxOpCall,UnaryOpCall,UnarySyntaxOpCall,ConditionalOpCall,WhereOpCall}
    print(io, T.name.name, "  ", x.fullspan, " (", x.span, ")")
    print(io)
end
Base.show(io::IO, x::T) where T <: Union{BinaryOpCall,BinarySyntaxOpCall,UnaryOpCall,UnarySyntaxOpCall,ConditionalOpCall,WhereOpCall,IDENTIFIER,LITERAL} = AbstractTrees.print_tree(io, x, 3)

function AbstractTrees.printnode(io::IO, x::IDENTIFIER)
    print(io, "ID: ", x.val,"  ", x.fullspan, " (", x.span, ")")
    print(io)
end

function AbstractTrees.printnode(io::IO, x::T) where T <: LITERAL
    print(io, T.name.name,": ", x.val,"  ", x.fullspan, " (", x.span, ")")
    print(io)
end
function AbstractTrees.printnode(io::IO, x::T) where T <: OPERATOR
    print(io, "OP: ", T.parameters[2]," ", x.fullspan, " (", x.span, ")")
    print(io)
end

