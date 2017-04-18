function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte ranges = @default ps parse_ranges(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)
    next(ps)
    ret = EXPR(kw, SyntaxNode[ranges, block], ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])

    # Linting
    if ranges isa EXPR && ranges.head == BLOCK
        for r in ranges.args
            _lint_range(ps, r, startbyte + kw.span + (0:ranges.span))
        end
    else
        _lint_range(ps, ranges, startbyte + kw.span + (0:ranges.span))
    end

    return ret
end

function _lint_range(ps::ParseState, x, loc)
    if !(x isa EXPR && (x.head isa OPERATOR{1, Tokens.EQ} || (x.head == CALL && x.args[1] isa OPERATOR{6, Tokens.IN})))
        push!(ps.diagnostics, Hint{Hints.RangeNonAssignment}(loc))
    end
end

function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    
    arg = @closer ps range @closer ps comma @closer ps ws parse_expression(ps)
    if ps.nt.kind == Tokens.COMMA
        indices = EXPR(BLOCK, [arg], arg.span)
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(indices.punctuation, INSTANCE(ps))
            format_comma(ps)
                
            indices.span += last(indices.punctuation).span
            @catcherror ps startbyte push!(indices.args, @closer ps comma @closer ps ws parse_expression(ps))
            indices.span += last(indices.args).span
        end
    else
        indices = arg
    end
    return indices
end


function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte cond = @default ps @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)
    next(ps)

    ret = EXPR(kw, SyntaxNode[cond, block], ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])

    # Linting
    if cond isa EXPR && cond.head isa OPERATOR{1}
        push!(ps.diagnostics, Hint{Hints.CondAssignment}(start + kw.span + (0:cond.span)))
    end
    if cond isa LITERAL{Tokens.FALSE}
        push!(ps.diagnostics, Hint{Hints.DeadCode}(start:ps.nt.startbyte))
    end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    return EXPR(INSTANCE(ps), SyntaxNode[], ps.nt.startbyte - ps.t.startbyte)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    return EXPR(INSTANCE(ps), SyntaxNode[], ps.nt.startbyte - ps.t.startbyte)
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