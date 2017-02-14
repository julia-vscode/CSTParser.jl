function next(x::EXPR, s::Iterator{:const})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:global})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:local})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:return})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end