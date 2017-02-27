function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    start = ps.t.startbyte
    start_col = ps.t.startpos[2]
    kw = INSTANCE(ps)
    ranges = @default ps @closer ps block parse_ranges(ps)
    block = @default ps parse_block(ps, start_col)
    next(ps)
    return EXPR(kw, Expression[ranges, block], ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)])
end


function parse_ranges(ps::ParseState)
    arg = @closer ps comma @closer ps ws parse_expression(ps)
    if ps.nt.kind == Tokens.COMMA
        indices = EXPR(BLOCK, [arg], arg.span)
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(indices.punctuation, INSTANCE(ps))
            indices.span += last(indices.punctuation).span
            format(ps)
            push!(indices.args, @closer ps comma @closer ps block @closer ps ws parse_expression(ps))
            indices.span += last(indices.args).span
        end
    else
        indices = arg
    end
    return indices
end


function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    start = ps.t.startbyte
    start_col = ps.t.startpos[2]
    kw = INSTANCE(ps)
    arg = @default ps @closer ps block @closer ps ws parse_expression(ps)
    block = @default ps parse_block(ps, start_col)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    start = ps.t.startbyte
    return EXPR(INSTANCE(ps), Expression[], ps.nt.startbyte - start)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    start = ps.t.startbyte
    return EXPR(INSTANCE(ps), Expression[], ps.nt.startbyte - start)
end

_start_for(x::EXPR) = Iterator{:for}(1, 4)
_start_while(x::EXPR) = Iterator{:while}(1, 4)



function next(x::EXPR, s::Iterator{:while})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:for})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:continue})
    if s.i == 1
        return x.head, +s
    end
end

function next(x::EXPR, s::Iterator{:break})
    if s.i == 1
        return x.head, +s
    end
end