function Base.show{T, K}(io::IO, x::INSTANCE{T,K},indent=0)
    println(io, " "^indent, " $((Tokens.Kind[K][1]))","    [",x.span,"]")
end

function Base.show{T}(io::IO, x::INSTANCE{T,:globalrefdoc},indent=0)
    println(io, " "^indent, " @doc","    [",x.span,"]")
end

function Base.show(io::IO, x::QUOTENODE,indent=0)
    println(io, " "^indent, " QUOTENODE")
end

function Base.show(io::IO, x::EXPR,indent=0)
    name = sprint(show, x.head)
    println(io, " "^indent, "↘ ", name,"    [", x.span, "]")
    for a in x.args[(1+(x.head==CALL)):end]
        show(io, a, indent+1)
    end 
end

function Base.show{T}(io::IO, x::Scope{T},indent=0)
    println(io, " "^indent, "↘ ", T)
    for a in x.args
        show(io, a, indent+1)
    end 
end

function Base.show(io::IO, x::Variable,indent=0)
    println(io, " "^indent, "→ ","Variable")
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
