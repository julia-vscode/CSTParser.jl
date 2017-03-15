parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORT}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORTALL}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.USING}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.EXPORT}}) = parse_export(ps)

function parse_kw(ps::ParseState, ::Type{Val{Tokens.MODULE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    scope = Scope{Tokens.MODULE}(get_id(arg), [])
    block = @scope ps scope parse_block(ps)
    next(ps)
    push!(ps.current_scope.args, scope)
    return EXPR(kw, [TRUE, arg, block], ps.nt.startbyte - start, [INSTANCE(ps)], scope)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BAREMODULE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    scope = Scope{Tokens.MODULE}(get_id(arg), [])
    block = @scope ps scope parse_block(ps)
    next(ps)
    push!(ps.current_scope.args, scope)
    return EXPR(kw, [FALSE, arg, block], ps.nt.startbyte - start, [INSTANCE(ps)], scope)
end

function parse_dot_mod(ps::ParseState)
    args = []
    puncs = []

    while ps.nt.kind==Tokens.DOT || ps.nt.kind==Tokens.DDOT || ps.nt.kind==Tokens.DDDOT
        next(ps)
        d = INSTANCE(ps)
        for i = 1:d.span
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1, ps.nt.startbyte+i))
        end
    end

    while true
        next(ps)
        if ps.t.kind == Tokens.AT_SIGN
            next(ps)
            a = INSTANCE(ps)
            a.val = Symbol('@', a.val)
            a.span +=1
            a.offset -=1
            push!(args, a)
        elseif ps.t.kind == Tokens.LPAREN
            a = EXPR(HEAD{InvisibleBrackets}(0, 0), [], -ps.t.startbyte, [INSTANCE(ps)])
            push!(a.args, @default ps @closer ps paren parse_expression(ps))
            next(ps)
            push!(a.punctuation, INSTANCE(ps))
            push!(args, a)
        else
            push!(args, INSTANCE(ps))
        end
        if ps.nt.kind != Tokens.DOT
            break
        else
            next(ps)
            push!(puncs, INSTANCE(ps))
        end
    end
    args, puncs
end


function parse_imports(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    tk = ps.t.kind

    arg, puncs = parse_dot_mod(ps)

    if ps.nt.kind!=Tokens.COMMA && ps.nt.kind!=Tokens.COLON
        return EXPR(kw, arg, ps.nt.startbyte - start, puncs)
    end

    if ps.nt.kind == Tokens.COLON
        ret = EXPR(TOPLEVEL,[], 0, [kw])
        t = 0
        for t = 1:length(puncs)-length(arg)+1
            push!(ret.punctuation, puncs[t])
        end

        next(ps)
        push!(puncs, INSTANCE(ps))
        for i = 1:length(arg)
            push!(ret.punctuation, arg[i])
            push!(ret.punctuation, puncs[i + t])
        end
        
        M = arg
        arg, puncs = parse_dot_mod(ps)
        push!(ret.args, EXPR(KEYWORD{tk}(0,0), arg, sum(x.span for x in arg) + length(arg)-1, puncs))
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            arg, puncs = parse_dot_mod(ps)
            push!(ret.args, EXPR(KEYWORD{tk}(0,0), arg, sum(x.span for x in arg) + length(arg)-1, puncs))
        end
    else
        ret = EXPR(TOPLEVEL,[], 0, [kw])
        push!(ret.args, EXPR(KEYWORD{tk}(0,0), arg, sum(x.span for x in arg) + length(arg)-1, puncs))
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            arg, puncs = parse_dot_mod(ps)
            push!(ret.args, EXPR(KEYWORD{tk}(0,0), arg, sum(x.span for x in arg) + length(arg)-1, puncs))
        end
    end
    
    # Linting
    if ps.current_scope isa Scope{Tokens.FUNCTION}
        push!(ps.hints, Hint{Hints.ImportInFunction}(kw.offset + (1:ret.span)))
    end

    ret.span = ps.nt.startbyte - start
    return ret
end

function parse_export(ps::ParseState)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    
    ret = EXPR(kw, parse_dot_mod(ps)[1], 0, [])
    
    while ps.nt.kind == Tokens.COMMA
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
        arg = parse_dot_mod(ps)[1][1]
        push!(ret.args, arg)
    end
    
    if ps.current_scope isa Scope{Tokens.FUNCTION}
        push!(ps.hints, Hint{Hints.ImportInFunction}(kw.offset + (1:ret.span)))
    end
    ret.span = ps.nt.startbyte - start
    return ret
end

function _start_imports(x::EXPR)
    # return Iterator{:imports}(1, (x.head.span>0) + length(x.args) + length(x.punctuation)) 
    return Iterator{:imports}(1,1)
end

function _start_toplevel(x::EXPR)
    if !(x.args[1] isa EXPR && (x.args[1].head isa KEYWORD{Tokens.IMPORT} || x.args[1].head isa KEYWORD{Tokens.IMPORTALL} || x.args[1].head isa KEYWORD{Tokens.USING})) 
        return Iterator{:toplevelblock}(1, length(x.args) + length(x.punctuation))
    else
        # return Iterator{:toplevel}(1, length(x.args) + length(x.punctuation))
        return Iterator{:toplevel}(1,1)
    end
end

next(x::EXPR, s::Iterator{:imports}) = x, +s

# function next(x::EXPR, s::Iterator{:imports})
#     ndots = length(x.punctuation) - length(x.args) + 1
#     if x.head.span == 0
#         if s.i <= ndots
#             return x.punctuation[s.i], +s
#         elseif isodd(s.i + ndots)
#             return x.args[div(s.i + 1 - ndots, 2)], +s
#         else
#             return PUNCTUATION{Tokens.DOT}(1,0), +s
#         end
#     else
#         if s.i == 1
#             return x.head, +s
#         elseif s.i <=ndots+1
#             return x.punctuation[s.i - 1], +s
#         elseif isodd(s.i+ndots) 
#             return PUNCTUATION{Tokens.DOT}(1,0), +s
#         else
#             return x.args[div(s.i - ndots, 2)], +s
#         end
#     end
# end

function next(x::EXPR, s::Iterator{:export})
    if s.i == 1
        return x.head, +s
    elseif isodd(s.i)
        return x.punctuation[div(s.i-1, 2)], +s
    else
        return x.args[div(s.i, 2)], +s
    end
end


function next(x::EXPR, s::Iterator{:module})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:toplevel})
    col = findfirst(x-> x isa OPERATOR{8, Tokens.COLON}, x.punctuation)
    if col > 0
        if s.i ≤ col
            return x.punctuation[s.i], +s
        else
            d = s.i - col
            if isodd(d)
                return x.args[div(d + 1, 2)], +s
            else
                return x.punctuation[div(d, 2) + col], +s
            end
        end
    else
        if s.i == 1
            return x.punctuation[1], +s
        elseif iseven(s.i)
            return x.args[div(s.i, 2)], +s
        else
            return x.punctuation[div(s.i+1, 2)], +s
        end
    end
end
