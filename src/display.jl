# function Base.show{T, K}(io::IO, x::INSTANCE{T,K},indent=0)
#     println(io, " "^indent, " $((Tokens.Kind[K][1]))","    [",x.span,"]")
# end

Base.show(io::IO, x::IDENTIFIER, indent = 0) =
    println(io, "  "^indent, " $(x.val)")

Base.show(io::IO, x::LITERAL{nothing}, indent = 0) =
    println(io, "  "^indent, " nothing", "    [", x.span, "]")

Base.show(io::IO, x::LITERAL{K}, indent = 0) where {K} =
    println(io, "  "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show(io::IO, x::KEYWORD{K}, indent = 0) where {K} =
    println(io, "  "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show(io::IO, x::OPERATOR{P,K}, indent = 0) where {P,K} =
    println(io, "  "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show(io::IO, x::PUNCTUATION{K}, indent = 0) where {K} =
    println(io, "  "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

Base.show(io::IO, x::HEAD{:file}, indent = 0) =
    println(io, "  "^indent, " file", "    [", x.span, "]")

Base.show(io::IO, x::HEAD{K}, indent = 0) where {K} =
    println(io, "  "^indent, " $((Tokens.Kind[K][1]))", "    [", x.span, "]")

function Base.show(io::IO, x::HEAD{:globalrefdoc}, indent = 0)
    println(io, "  "^indent, " @doc", "    [", x.span, "]")
end


function Base.show(io::IO, x::ERROR, indent = 0)
    println(io, "  "^indent, " ERROR")
end

function Base.show(io::IO, x::EXPR{T}, indent = 0) where T
    name = sprint(show, T)
    print(io, "  "^indent, T)
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
