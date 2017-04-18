parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORT}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMPORTALL}}) = parse_imports(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.USING}}) = parse_imports(ps)

parse_kw(ps::ParseState, ::Type{Val{Tokens.MODULE}}) = parse_module(ps)
parse_kw(ps::ParseState, ::Type{Val{Tokens.BAREMODULE}}) = parse_module(ps)

function parse_module(ps::ParseState)
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte arg = @closer ps block @closer ps ws parse_expression(ps)

    block = EXPR(BLOCK, [], -ps.nt.startbyte)
    @scope ps Scope{Tokens.MODULE} @default ps while ps.nt.kind !== Tokens.END
        @catcherror ps startbyte a = @closer ps block parse_doc(ps)
        push!(block.args, a)
    end

    # Construction
    block.span += ps.nt.startbyte
    next(ps)
    ret = EXPR(kw, [(kw isa KEYWORD{Tokens.MODULE} ? TRUE : FALSE), arg, block], ps.nt.startbyte - startbyte, [INSTANCE(ps)])
    ret.defs = [Variable(Expr(arg), :module, ret)]
    return ret
end

function parse_dot_mod(ps::ParseState)
    startbyte = ps.nt.startbyte
    args = []
    puncs = []

    while ps.nt.kind == Tokens.DOT || ps.nt.kind == Tokens.DDOT || ps.nt.kind == Tokens.DDDOT
        next(ps)
        d = INSTANCE(ps)
        if d isa OPERATOR{15,Tokens.DOT}
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
        elseif d isa OPERATOR{8,Tokens.DDOT}
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
        elseif d isa OPERATOR{0,Tokens.DDDOT}
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
            push!(puncs, OPERATOR{15,Tokens.DOT,false}(1))
        end
    end

    # import/export ..
    if ps.nt.kind == Tokens.COMMA || ps.ws.kind == NewLineWS || ps.nt.kind == Tokens.ENDMARKER
        if length(puncs) == 2
            return [INSTANCE(ps)], []
        end
    end

    while true
        if ps.nt.kind == Tokens.AT_SIGN
            next(ps)
            next(ps)
            a = INSTANCE(ps)
            # a.val = Symbol('@', a.val)
            # a.span +=1
            a = IDENTIFIER(a.span + 1, Symbol('@', Expr(a)))
            push!(args, a)
        elseif ps.nt.kind == Tokens.LPAREN
            next(ps)
            a = EXPR(HEAD{InvisibleBrackets}(0), [], -ps.t.startbyte, [INSTANCE(ps)])
            @catcherror ps startbyte push!(a.args, @default ps @closer ps paren parse_expression(ps))
            next(ps)
            push!(a.punctuation, INSTANCE(ps))
            push!(args, a)
        elseif ps.nt.kind == Tokens.EX_OR
            @catcherror ps startbyte a = @closer ps comma parse_expression(ps)
            push!(args, a)
        elseif isoperator(ps.nt) && ps.ndot
            next(ps)
            push!(args, OPERATOR{precedence(ps.t), ps.t.kind, false}(ps.nt.startbyte-ps.t.startbyte - 1))
        else
            next(ps)
            push!(args, INSTANCE(ps))
        end

        if ps.nt.kind == Tokens.DOT
            next(ps)
            push!(puncs, INSTANCE(ps))
        elseif isoperator(ps.nt) && ps.ndot
            push!(puncs, PUNCTUATION{Tokens.DOT}(1))
        else
            break
        end
        # if ps.nt.kind != Tokens.DOT
        #     break
        # else
        #     next(ps)
        #     push!(puncs, INSTANCE(ps))
        # end
    end
    args, puncs
end


function parse_imports(ps::ParseState)
    startbyte = ps.t.startbyte
    kw = INSTANCE(ps)
    tk = ps.t.kind

    arg, puncs = parse_dot_mod(ps)

    if ps.nt.kind != Tokens.COMMA && ps.nt.kind != Tokens.COLON
        ret = EXPR(kw, arg, ps.nt.startbyte - startbyte, puncs)
        ret.defs = [Variable(Expr(ret), :IMPORTS, ret)]
        return ret
    end

    if ps.nt.kind == Tokens.COLON
        ret = EXPR(TOPLEVEL, [], 0, [kw])
        t = 0
        for t = 1:length(puncs) - length(arg) + 1
            push!(ret.punctuation, puncs[t])
        end

        next(ps)
        push!(puncs, INSTANCE(ps))
        for i = 1:length(arg)
            push!(ret.punctuation, arg[i])
            push!(ret.punctuation, puncs[i + t])
        end
        
        M = arg
        @catcherror ps startbyte arg, puncs = parse_dot_mod(ps)
        push!(ret.args, EXPR(KEYWORD{tk}(0), arg, sum(x.span for x in arg) + length(arg) - 1, puncs))
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            @catcherror ps startbyte arg, puncs = parse_dot_mod(ps)
            push!(ret.args, EXPR(KEYWORD{tk}(0), arg, sum(x.span for x in arg) + length(arg) - 1, puncs))
        end
        ret.defs = [Variable(d, :IMPORTS, ret) for d in Expr(ret).args]
    else
        ret = EXPR(TOPLEVEL, [], 0, [kw])
        push!(ret.args, EXPR(KEYWORD{tk}(0), arg, sum(x.span for x in arg) + length(arg) - 1, puncs))
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            @catcherror ps startbyte arg, puncs = parse_dot_mod(ps)
            push!(ret.args, EXPR(KEYWORD{tk}(0), arg, sum(x.span for x in arg) + length(arg) - 1, puncs))
        end
        ret.defs = [Variable(d, :IMPORTS, ret) for d in Expr(ret).args]
    end
    
    # Linting
    if ps.current_scope isa Scope{Tokens.FUNCTION}
        push!(ps.diagnostics, Hint{Hints.ImportInFunction}(startbyte:ps.nt.startbyte))
    end

    ret.span = ps.nt.startbyte - startbyte
    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.EXPORT}})
    startbyte = ps.t.startbyte

    # Parsing
    kw = INSTANCE(ps)
    ret = EXPR(kw, parse_dot_mod(ps)[1], 0, [])
    
    while ps.nt.kind == Tokens.COMMA
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
        @catcherror ps startbyte arg = parse_dot_mod(ps)[1][1]
        push!(ret.args, arg)
    end
    ret.span = ps.nt.startbyte - startbyte

    # Linting

    # check for duplicates
    let idargs = filter(a -> a isa IDENTIFIER, ret.args)
        if length(idargs) != length(unique((a -> a.val).(idargs)))
            push!(ps.diagnostics, Hint{Hints.DuplicateArgument}(startbyte:ps.nt.startbyte))
        end
    end
    if ps.current_scope isa Scope{Tokens.FUNCTION}
        push!(ps.diagnostics, Hint{Hints.ImportInFunction}(startbyte:ps.nt.startbyte))
    end
    return ret
end



function _start_imports(x::EXPR)
    # return Iterator{:imports}(1, (x.head.span>0) + length(x.args) + length(x.punctuation)) 
    return Iterator{:imports}(1, 1)
end

function _start_toplevel(x::EXPR)
    if !all(x.args[i] isa EXPR && (x.args[i].head isa KEYWORD{Tokens.IMPORT} || x.args[i].head isa KEYWORD{Tokens.IMPORTALL} || x.args[i].head isa KEYWORD{Tokens.USING}) for i = 1:length(x.args)) 
        return Iterator{:toplevelblock}(1, length(x.args) + length(x.punctuation))
    else
        # return Iterator{:toplevel}(1, length(x.args) + length(x.punctuation))
        return Iterator{:toplevel}(1, 1)
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
        return x.punctuation[div(s.i - 1, 2)], +s
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
    col = findfirst(x -> x isa OPERATOR{8, Tokens.COLON}, x.punctuation)
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
            return x.punctuation[div(s.i + 1, 2)], +s
        end
    end
end
