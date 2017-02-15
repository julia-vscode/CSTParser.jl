function next(x::EXPR, s::Iterator{:tuple})
    if isodd(s.i)
        return x.punctuation[div(s.i+1, 2)], +s
    elseif s.i==s.n
        return last(x.punctuation), +s
    else
        return x.args[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:tuplenoparen})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end