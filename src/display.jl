# function Base.show{T, K}(io::IO, x::INSTANCE{T,K},indent=0)
#     println(io, " "^indent, " $((Tokens.Kind[K][1]))","    [",x.span,"]")
# end

Base.show(io::IO, x::IDENTIFIER, indent = 0) =
    println(io, " "^indent, " $(x.val)", "    [", x.span, "]")

Base.show(io::IO, x::LITERAL{nothing}, indent = 0) =
    println(io, " "^indent, " nothing", "    [", x.span, "]")

Base.show{K}(io::IO, x::LITERAL{K}, indent = 0) =
    println(io, " "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show{K}(io::IO, x::KEYWORD{K}, indent = 0) =
    println(io, " "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show{P,K}(io::IO, x::OPERATOR{P,K}, indent = 0) =
    println(io, " "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show{K}(io::IO, x::PUNCTUATION{K}, indent = 0) =
    println(io, " "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show(io::IO, x::HEAD{:file}, indent = 0) =
    println(io, " "^indent, " file", "    [", x.span, "]")

Base.show{K}(io::IO, x::HEAD{K}, indent = 0) =
    println(io, " "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

function Base.show(io::IO, x::HEAD{:globalrefdoc}, indent = 0)
    println(io, " "^indent, " @doc", "    [", x.span, "]")
end

function Base.show(io::IO, x::QUOTENODE, indent = 0)
    println(io, " "^indent, " QUOTENODE")
end

function Base.show(io::IO, x::ERROR, indent = 0)
    println(io, " "^indent, " ERROR")
end

function Base.show(io::IO, x::EXPR, indent = 0)
    name = sprint(show, x.head)
    println(io, " "^indent, "↘ ", name, "    [", x.span, "]")
    for a in x.args[(1 + (x.head == CALL)):end]
        show(io, a, indent + 1)
    end 
end

function Base.show{T}(io::IO, x::Scope{T}, indent = 0)
    print(io, " "^indent, "↘ ", T, " (", length(x.args), ") ")
    println("[", join(collect(a.id.val for a in x.args if a isa Variable), ", "), "]")
    for a in x.args
        if a isa Scope
            show(io, a, indent + 1)
        end
    end 
end

function Base.show(io::IO, x::Variable, indent = 0)
    println(io, " "^indent, "→ ", "Variable")
end


# import Base.print
# function print(io::IO, x::EXPR)
#     for a in x
#         print(io, a)
#     end
# end

# function print(io::IO, x::INSTANCE)
#     print(io, x.val,x.ws)
# end
# function print(io::IO, x::QUOTENODE)
#     print(io, x.val)
# end
