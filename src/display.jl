function Base.show(io::IO, x::EXPR, offset = 0, d = 0, er = false)
    T = typof(x)
    c =  T === ErrorToken || er ? :red : :normal
    print(io, rpad(offset, 3), " ", rpad(x.fullspan, 3), " ", rpad(x.span, 3), "| ")
    if isidentifier(x)
        printstyled(io, " "^d, typof(x) == NONSTDIDENTIFIER ? valof(x.args[2]) : valof(x), color = :yellow)
        x.meta !== nothing && show(io, x.meta)
        println(io)
    elseif isoperator(x)
        printstyled(io, " "^d, "OP: ", kindof(x), "\n", color = c)
    elseif iskw(x)
        printstyled(io, " "^d, kindof(x), "\n", color = :magenta)
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
            printstyled(io, " "^d, "PUNC: ", kindof(x), "\n", color = c)
        end
    elseif isliteral(x)
        printstyled(io, " "^d, "$(kindof(x)): ", valof(x), "\n", color = c)
    else
        printstyled(io, " "^d, T, color = c)
        if x.meta !== nothing
            print(io, "( ")
            show(io, x.meta)
            print(io, ")")
        end
        println(io)
        x.args === nothing && return
        for a in x.args
            show(io, a, offset, d + 1, er)
            offset += a.fullspan
        end
    end
end
