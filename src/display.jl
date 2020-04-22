function Base.show(io::IO, x::EXPR, d = 0, er = false)
    T = typof(x)
    c =  T === ErrorToken || er ? :red : :normal
    if isidentifier(x)
        printstyled(io, " "^d, typof(x) == NONSTDIDENTIFIER ? valof(x.args[2]) : valof(x), "  ", x.fullspan, "(", x.span, ") ", color = :yellow)
        x.meta !== nothing && show(io, x.meta)
        println(io)
    elseif isoperator(x)
        printstyled(io, " "^d, "OP: ", kindof(x), "  ", x.fullspan, "(", x.span, ")\n", color = c)
    elseif iskw(x)
        printstyled(io, " "^d, kindof(x), "  ", x.fullspan, "(", x.span, ")\n", color = :magenta)
    elseif ispunctuation(x)
        if kindof(x) == Tokens.LPAREN
            printstyled(io, " "^d, "(\n", color = c)
        elseif kindof(x) == Tokens.RPAREN
            printstyled(io, " "^d, ")\n", color = c)
        elseif kindof(x) == Tokens.LSQUARE
            printstyled(io, " "^d, "[\n", color = c)
        elseif kindof(x) == Tokens.RSQUARE
            printstyled(io, " "^d, "]\n", color = c)
        elseif kindof(x) == Tokens.COMMA
            printstyled(io, " "^d, ",\n", color = c)
        else
            printstyled(io, " "^d, "PUNC: ", kindof(x), "  ", x.fullspan, "(", x.span, ")\n", color = c)
        end
    elseif isliteral(x)
        printstyled(io, " "^d, "$(kindof(x)): ", valof(x), "  ", x.fullspan, "(", x.span, ")\n", color = c)
    else
        printstyled(io, " "^d, T, "  ", x.fullspan, "(", x.span, ")", color = c)
        x.meta !== nothing && show(io, x.meta)
        println(io)
        x.args === nothing && return
        for a in x.args
            show(io, a, d + 1, er)
        end
    end
end
