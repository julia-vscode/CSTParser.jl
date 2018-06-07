# function AbstractTrees.printnode(io::IO, x::EXPR{T}) where T
#     print(io, T, "  ", x.fullspan, " (", x.span, ")")
#     print(io)
# end
# Base.show(io::IO, x::EXPR) = AbstractTrees.print_tree(io, x, 3)

# function AbstractTrees.printnode(io::IO, x::T) where T <: Union{BinaryOpCall,BinarySyntaxOpCall,UnaryOpCall,UnarySyntaxOpCall,ConditionalOpCall,WhereOpCall}
#     print(io, T.name.name, "  ", x.fullspan, " (", x.span, ")")
#     print(io)
# end
# Base.show(io::IO, x::T) where T <: Union{BinaryOpCall,BinarySyntaxOpCall,UnaryOpCall,UnarySyntaxOpCall,ConditionalOpCall,WhereOpCall,IDENTIFIER,LITERAL} = AbstractTrees.print_tree(io, x, 3)

# function AbstractTrees.printnode(io::IO, x::IDENTIFIER)
#     print(io, "ID: ", x.val,"  ", x.fullspan, " (", x.span, ")")
#     print(io)
# end

# function AbstractTrees.printnode(io::IO, x::T) where T <: LITERAL
#     print(io, T.name.name,": ", x.val,"  ", x.fullspan, " (", x.span, ")")
#     print(io)
# end
# function AbstractTrees.printnode(io::IO, x::OPERATOR)
#     print(io, "OP: ", x.kind," ", x.fullspan, " (", x.span, ")")
#     print(io)
# end


function Base.show(io::IO, x::EXPR{T}, d = 0) where T
    println(io, " "^d, T, "  ", x.fullspan, " (", x.span, ")")
    for a in x.args
        show(io, a, d + 1)
    end
end

function Base.show(io::IO, x::T, d = 0) where T <: Union{BinaryOpCall,BinarySyntaxOpCall,UnaryOpCall,UnarySyntaxOpCall,ConditionalOpCall,WhereOpCall}
    println(io, " "^d, T.name.name, "  ", x.fullspan, " (", x.span, ")")
    for a in x
        show(io, a, d + 1)
    end
end

function Base.show(io::IO, x::IDENTIFIER, d = 0) 
    println(io, " "^d, "ID: ", x.val, "  ", x.fullspan, " (", x.span, ")")
end

function Base.show(io::IO, x::PUNCTUATION, d = 0) 
    if x.kind == Tokens.LPAREN
        println(io, " "^d, "(")
    elseif x.kind == Tokens.RPAREN
        println(io, " "^d, ")")
    elseif x.kind == Tokens.LSQUARE
        println(io, " "^d, "[")
    elseif x.kind == Tokens.RSQUARE
        println(io, " "^d, "]")
    elseif x.kind == Tokens.COMMA
        println(io, " "^d, ",")
    else
        println(io, " "^d, "PUNC: ", x.kind, "  ", x.fullspan, " (", x.span, ")")
    end
end

function Base.show(io::IO, x::OPERATOR, d = 0) 
    println(io, " "^d, "OP: ", x.kind, "  ", x.fullspan, " (", x.span, ")")
end

function Base.show(io::IO, x::LITERAL, d = 0) 
    println(io, " "^d, "LITERAL: ", x.val, "  ", x.fullspan, " (", x.span, ")")
end

function Base.show(io::IO, x::KEYWORD, d = 0) 
    println(io, " "^d, "KEY: ", x.kind, "  ", x.fullspan, " (", x.span, ")")
end