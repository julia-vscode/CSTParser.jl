function Base.show(io::IO, x::EXPR, d = 0, er = false)
    T = x.typ
    c =  T === ErrorToken || er ? :red : :normal
    if isidentifier(x)
        printstyled(io, " "^d, x.val, "  ", x.fullspan, "(", x.span, ")", color = :yellow)
        x.binding != nothing && printstyled(" $(x.binding.name)", x.binding.t === nothing ? "" : "::", color = :blue)
        println()
    elseif isoperator(x)
        printstyled(io, " "^d, "OP: ", x.kind, "  ", x.fullspan, "(", x.span, ")\n", color = c)
    elseif iskw(x)
        printstyled(io, " "^d, x.kind, "  ", x.fullspan, "(", x.span, ")\n", color = :magenta)
    elseif ispunctuation(x)
        if x.kind == Tokens.LPAREN
            printstyled(io, " "^d, "(\n", color = c)
        elseif x.kind == Tokens.RPAREN
            printstyled(io, " "^d, ")\n", color = c)
        elseif x.kind == Tokens.LSQUARE
            printstyled(io, " "^d, "[\n", color = c)
        elseif x.kind == Tokens.RSQUARE
            printstyled(io, " "^d, "]\n", color = c)
        elseif x.kind == Tokens.COMMA
            printstyled(io, " "^d, ",\n", color = c)
        else
            printstyled(io, " "^d, "PUNC: ", x.kind, "  ", x.fullspan, "(", x.span, ")\n", color = c)
        end
    elseif isliteral(x)
        printstyled(io, " "^d, "$(x.kind): ", x.val, "  ", x.fullspan, "(", x.span, ")\n", color = c)
    else
        printstyled(io, " "^d, T, "  ", x.fullspan, "(", x.span, ")", color = c)
        x.scope != nothing && printstyled(io, " new scope", color = :green)
        x.binding != nothing && printstyled(io, " $(x.binding.name)", x.binding.t === nothing ? "" : "::", color = :blue)
        println()
        x.args == nothing && return
        for a in x.args
            show(io, a, d + 1, er)
        end
    end
end

function Base.show(io::IO, scope::Scope)
    println(io, scope.parent === nothing ? "Root scope:" : "Scope:")
    println(io, scope.names isa Dict ? string("[", join(collect(keys(scope.names)), ","), "]") : "[]")
    println(io, scope.modules isa Dict ? string("[", join(collect(keys(scope.modules)), ","), "]") : "[]")
end


