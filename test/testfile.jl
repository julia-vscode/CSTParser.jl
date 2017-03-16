macro enum(T,syms...)
    for s in syms
        if isa(s,Symbol)
            if i == typemin(basetype) && !isempty(vals)
                throw(ArgumentError("overflow in value \"$s\" of Enum $typename"))
            end
        elseif isa(s,Expr) &&
               (s.head == :(=) || s.head == :kw) &&
               length(s.args) == 2 && isa(s.args[1],Symbol)
            i = eval(current_module(),s.args[2]) # allow exprs, e.g. uint128"1"
            if !isa(i, Integer)
                throw(ArgumentError("invalid value for Enum $typename, $s=$i; values must be integers"))
            end
            i = convert(basetype, i)
            s = s.args[1]
            hasexpr = true
        else
            throw(ArgumentError(string("invalid argument for Enum ", typename, ": ", s)))
        end
    end
end
