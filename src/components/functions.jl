# Functions
#   definition
#   short form definition
#   call

function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    start = ps.t.startbyte
    start_col = ps.t.startpos[2]
    kw = INSTANCE(ps)
    sig = @default ps @closer ps block @closer ps ws parse_expression(ps)
    scope = Scope{Tokens.FUNCTION}(get_id(sig), [])
    @scope ps scope _lint_func_sig(ps, sig)
    block = @default ps @scope ps scope parse_block(ps, start_col)
    next(ps)
    args = isempty(block.args) ? SyntaxNode[sig] : SyntaxNode[sig, block]
    push!(ps.current_scope.args, scope)
    return EXPR(kw, args, ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)], scope)
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret)
    next(ps)
    if ret isa IDENTIFIER && ret.val == :ccall
        ret = EXPR(ret, [], ret.span - ps.t.startbyte, [INSTANCE(ps)])
    else
        ret = EXPR(CALL, [ret], ret.span - ps.t.startbyte, [INSTANCE(ps)])
    end
    format(ps)
    
    @noscope ps @nocloser ps newline @closer ps comma @closer ps paren while !closer(ps)
        a = parse_expression(ps)
        if a isa EXPR && a.head isa OPERATOR{1, Tokens.EQ}
            a.head = HEAD{Tokens.KW}(a.head.span, a.head.offset)
        end
        push!(ret.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            format(ps)
            push!(ret.punctuation, INSTANCE(ps))
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        # next(ps)
        # push!(ret.punctuation, INSTANCE(ps))
        paras = EXPR(PARAMETERS, [], -ps.nt.startbyte)
        @nocloser ps newline @nocloser ps semicolon @closer ps comma @closer ps brace while !closer(ps)
            a = parse_expression(ps)
            if a isa EXPR && a.head isa OPERATOR{1, Tokens.EQ}
                a.head = HEAD{Tokens.KW}(a.head.span, a.head.offset)
            end
            push!(paras.args, a)
            if ps.nt.kind == Tokens.COMMA
                next(ps)
                format(ps)
                push!(paras.punctuation, INSTANCE(ps))
            end
        end
        paras.span += ps.nt.startbyte
        push!(ret.args, paras)
    end
    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    format(ps)
    ret.span += ps.nt.startbyte
    return ret
end


# Iterators

_start_function(x::EXPR) = Iterator{:function}(1, 1 + length(x.args) + length(x.punctuation))

_start_parameters(x::EXPR) = Iterator{:parameters}(1, length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:function})    
    if s.i == 1
        return x.head, +s
    elseif s.i == s.n
        return x.punctuation[1], +s
    else
        return x.args[s.i - 1], +s
    end
end

function next(x::EXPR, s::Iterator{:call})
    if length(x.args)>0 && last(x.args) isa EXPR && last(x.args).head == PARAMETERS && s.i == (s.n-1)
        return last(x.args), +s
    end
    if  s.i==s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:parameters})
    if  isodd(s.i)
        return x.args[div(s.i+1, 2)] , +s
    elseif iseven(s.i)
        return x.punctuation[div(s.i, 2)], +s
    end
end


# Linting

function _lint_func_sig(ps::ParseState, sig::IDENTIFIER) end
    
function _lint_func_sig(ps::ParseState, sig::EXPR)
    if sig isa EXPR && sig.head isa OPERATOR{14, Tokens.DECLARATION}
        return _lint_func_sig(ps, sig.args[1])
    end
    fname = _get_fname(sig)
    args = Symbol[]
    nargs = length(sig.args) - 1
    firstkw  = nargs + 1
    for (i, arg) in enumerate(sig.args[2:end])
        if arg isa EXPR && arg.head isa OPERATOR{14, Tokens.DECLARATION} && length(arg.args) == 1
            #unhandled TYPE argument
            continue
        elseif arg isa EXPR && arg.head == PARAMETERS
            for (i1, arg1) in enumerate(arg.args)
                _lint_arg(ps, arg1, args, i + i1 -1, fname, nargs, i-1)
            end
        else
            _lint_arg(ps, arg, args, i, fname, nargs, firstkw)
        end
    end
end
    
function _lint_arg(ps::ParseState, arg, args, i, fname, nargs, firstkw)
    a = _arg_id(arg)
    !(a isa IDENTIFIER) && return
    push!(ps.current_scope.args, Variable(a, :Any, :argument))
    if !(a.val in args)
        push!(args, a.val)
    else 
        push!(ps.hints, Hint{Hints.DuplicateArgumentName}(a.offset + (1:arg.span)))
    end
    if a.val == Expr(fname)
        push!(ps.hints, Hint{Hints.ArgumentFunctionNameConflict}(a.offset + (1:arg.span)))
    end
    if arg isa EXPR && arg.head isa OPERATOR{0,Tokens.DDDOT} && i!=nargs
        push!(ps.hints, Hint{Hints.SlurpingPosition}(a.offset + (1:arg.span)))
    end
    if arg isa EXPR && arg.head isa HEAD{Tokens.KW} && i < firstkw
        firstkw = i
    end
    if !(arg isa EXPR && arg.head isa HEAD{Tokens.KW}) && i> firstkw
        push!(ps.hints, Hint{Hints.KWPosition}(a.offset + (1:arg.span)))
    end
end

function _lint_func_body(ps::ParseState, body)
end



_arg_id(x::INSTANCE) = x

function _arg_id(x::EXPR)
    if x.head isa OPERATOR{14, Tokens.DECLARATION} || x.head == CURLY || x.head isa OPERATOR{0, Tokens.DDDOT} || x.head isa HEAD{Tokens.KW}
        return _arg_id(x.args[1])
    else
        return x
    end
end


function _sig_params(x, p = [])
    if x isa EXPR
        if x.head == CURLY
            for a in x.args[2:end]
                push!(p, get_id(a))
            end
        end
    end
    return p
end

function _get_fname(sig)
    if sig isa EXPR && sig.head == TUPLE
        return NOTHING
    elseif sig isa EXPR && sig.head isa OPERATOR{14,Tokens.DECLARATION}
        get_id(sig.args[1].args[1])
    else
        get_id(sig.args[1])
    end
end