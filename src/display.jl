function AbstractTrees.printnode(io::IO, x::EXPR)
    print(io, x.head, "  ", x.fullspan, " (", x.span, ")")
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
function AbstractTrees.printnode(io::IO, x::OPERATOR)
    print(io, "OP: ", x.kind," ", x.fullspan, " (", x.span, ")")
    print(io)
end

