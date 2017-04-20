function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    @catcherror ps startbyte sig = @default ps @closer ps block @closer ps ws parse_expression(ps)

    if sig isa EXPR && sig.head isa HEAD{InvisibleBrackets} && !(sig.args[1] isa EXPR && sig.args[1].head == TUPLE)
        sig.args[1] = EXPR(TUPLE, [sig.args[1]], sig.args[1].span)
    end
    _lint_func_sig(ps, sig)
    @catcherror ps startbyte block = @default ps @scope ps Scope{Tokens.FUNCTION} parse_block(ps, start_col)
    

    # Construction
    if isempty(block.args)
        if sig isa EXPR
            args = SyntaxNode[sig, block]
        else
            args = SyntaxNode[sig]
        end
    else
        args = SyntaxNode[sig, block]
    end
    
    next(ps)
    ret = EXPR(kw, args, ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])
    ret.defs = [Variable(function_name(sig), :Function, ret)]
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret)
    startbyte = ps.t.startbyte
    # Parsing
    next(ps)
    if ret isa IDENTIFIER && ret.val == :ccall
        ret = HEAD{Tokens.CCALL}(ret.span)
        ret = EXPR(ret, [], ret.span - ps.t.startbyte, [INSTANCE(ps)])
    else
        ret = EXPR(CALL, [ret], ret.span - ps.t.startbyte, [INSTANCE(ps)])
    end
    format_lbracket(ps)
        
    @default ps @closer ps paren parse_comma_sep(ps, ret)

    next(ps)
    push!(ret.punctuation, INSTANCE(ps))
    format_rbracket(ps)
    ret.span += ps.nt.startbyte

    # Construction
    # fix arbitrary $ case
    if ret.args[1] isa OPERATOR{9, Tokens.EX_OR}
        ret.head = shift!(ret.args)
    end

    
    if length(ret.args) > 0 && ismacro(ret.args[1])
        ret.head = MACROCALL
    end
    if ret.head isa HEAD{Tokens.CCALL} && length(ret.args) > 1 && ret.args[2] isa IDENTIFIER && (ret.args[2].val == :stdcall || ret.args[2].val == :fastcall || ret.args[2].val == :cdecl || ret.args[2].val == :thiscall)
        arg = splice!(ret.args, 2)
        push!(ret.args, EXPR(arg, [], arg.span))
    end


    # Linting
    if (ret.args[1] isa IDENTIFIER && ret.args[1].val == :Dict) || (ret.args[1] isa EXPR && ret.args[1].head == CURLY && ret.args[1].args[1] isa IDENTIFIER && ret.args[1].args[1].val == :Dict)
        _lint_dict(ps, ret)
    end
    # fname = _get_fname(ret)
    # if fname isa IDENTIFIER && fname.val in keys(deprecated_symbols)
    #     push!(ps.diagnostics, Hint{Hints.Deprecation}(ps.nt.startbyte - ret.span + (0:(fname.span))))
    # end
    return ret
end

function parse_comma_sep(ps::ParseState, ret::EXPR, kw = true, block = false)
    startbyte = ps.nt.startbyte

    @catcherror ps startbyte @noscope ps @nocloser ps newline @closer ps comma while !closer(ps)
        a = parse_expression(ps)
        if kw && !ps.closer.brace && a isa EXPR && a.head isa OPERATOR{1, Tokens.EQ}
            a.head = HEAD{Tokens.KW}(a.head.span)
        end
        push!(ret.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.punctuation, INSTANCE(ps))
            format_comma(ps)
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        if block
            ret.head = BLOCK
            @nocloser ps newline  @closer ps comma while @nocloser ps semicolon !closer(ps)
                @catcherror ps startbyte a = parse_expression(ps)
                push!(ret.args, a)
            end

        else
            paras = EXPR(PARAMETERS, [], -ps.nt.startbyte)
            @nocloser ps newline @nocloser ps semicolon @closer ps comma while !closer(ps)
                @catcherror ps startbyte a = parse_expression(ps)
                if kw && !ps.closer.brace && a isa EXPR && a.head isa OPERATOR{1, Tokens.EQ}
                    a.head = HEAD{Tokens.KW}(a.head.span)
                end
                push!(paras.args, a)
                if ps.nt.kind == Tokens.COMMA
                    next(ps)
                    push!(paras.punctuation, INSTANCE(ps))
                    format_comma(ps)
                end
            end
            paras.span += ps.nt.startbyte
            push!(ret.args, paras)
        end
    end
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
    if length(x.args) > 0 && last(x.args) isa EXPR && last(x.args).head == PARAMETERS && s.i == (s.n - 1)
        return last(x.args), +s
    end
    if  s.i == s.n
        return last(x.punctuation), +s
    elseif isodd(s.i)
        return x.args[div(s.i + 1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

function next(x::EXPR, s::Iterator{:parameters})
    if  isodd(s.i)
        return x.args[div(s.i + 1, 2)], +s
    elseif iseven(s.i)
        return x.punctuation[div(s.i, 2)], +s
    end
end

_start_ccall(x::EXPR) = Iterator{:ccall}(1, 1 + length(x.args) + length(x.punctuation))

function next(x::EXPR, s::Iterator{:ccall})
    # if length(x.args)>0 && last(x.args) isa EXPR && last(x.args).head == PARAMETERS && s.i == (s.n-1)
    #     return last(x.args), +s
    # end
    if s.i == 1
        return x.head, +s
    elseif s.i == s.n
        return last(x.punctuation), +s
    elseif iseven(s.i)
        return x.punctuation[div(s.i, 2)], +s
    else
        return x.args[div(s.i - 1, 2)], +s
    end
end

next(x::EXPR, s::Iterator{:stdcall}) = x.head, +s


# Linting
# Signature
# [+] repeated argument names
# [+] argument/function name conflict
# [+] check slurping in last position only
# [+] check kw arguments order
# [] check all parameters are used specified
"""
    _lint_func_sig(ps, sig)

Runs linting on function argument, assumes `sig` has just been parsed such that 
the byte offset is `ps.nt.startbyte - sig.span`.
"""
function _lint_func_sig(ps::ParseState, sig::IDENTIFIER) end
    
function _lint_func_sig(ps::ParseState, sig::EXPR)
    loc = ps.nt.startbyte + (-sig.span:0)
    if sig isa EXPR && sig.head isa OPERATOR{14, Tokens.DECLARATION}
        return _lint_func_sig(ps, sig.args[1])
    end
    fname = _get_fname(sig)
    format_funcname(ps, function_name(sig), sig.span)
    args = Symbol[]
    nargs = length(sig.args) - 1
    firstkw  = nargs + 1
    for (i, arg) in enumerate(sig.args[2:end])
        if arg isa EXPR && arg.head isa OPERATOR{14, Tokens.DECLARATION} && length(arg.args) == 1
            #unhandled ::Type argument
            continue
        elseif arg isa EXPR && arg.head == PARAMETERS
            for (i1, arg1) in enumerate(arg.args)
                _lint_arg(ps, arg1, args, i + i1 - 1, fname, nargs, i - 1, loc)
            end
        else
            _lint_arg(ps, arg, args, i, fname, nargs, firstkw, loc)
        end
    end
    sig.defs = (a -> Variable(a, :Any, sig)).(args)
end
    
function _lint_arg(ps::ParseState, arg, args, i, fname, nargs, firstkw, loc)
    a = _arg_id(arg)
    !(a isa IDENTIFIER) && return
    # push!(ps.current_scope.args, Variable(a, :Any, :argument))
    if !(a.val in args)
        push!(args, a.val)
    else 
        push!(ps.diagnostics, Hint{Hints.DuplicateArgumentName}(loc))
    end
    if a.val == Expr(fname)
        push!(ps.diagnostics, Hint{Hints.ArgumentFunctionNameConflict}(loc))
    end
    if arg isa EXPR && arg.head isa OPERATOR{0,Tokens.DDDOT} && i != nargs
        push!(ps.diagnostics, Hint{Hints.SlurpingPosition}(loc))
    end
    if arg isa EXPR && arg.head isa HEAD{Tokens.KW} && i < firstkw
        firstkw = i
    end
    if !(arg isa EXPR && arg.head isa HEAD{Tokens.KW}) && i > firstkw
        push!(ps.diagnostics, Hint{Hints.KWPosition}(loc))
    end
    # Check 
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

function function_name(sig::SyntaxNode)
    if sig isa EXPR
        if sig.head == CALL || sig.head == CURLY
            return function_name(sig.args[1])
        elseif sig.head isa OPERATOR{15,Tokens.DOT}
            return function_name(sig.args[2])
        end
    elseif sig isa QUOTENODE
        function_name(sig.val)
    elseif sig isa IDENTIFIER
        return sig.val
    elseif sig isa OPERATOR
        return UNICODE_OPS_REVERSE[typeof(sig).parameters[2]]
    else
        error("$(Expr(sig)) is not a valid function name")
    end
end


function declares_function(x::SyntaxNode)
    if x isa EXPR
        if x.head isa KEYWORD{Tokens.FUNCTION}
            return true
        elseif x.head isa OPERATOR{1,Tokens.EQ} && x.args[1] isa EXPR && x.args[1].head == CALL
            return true
        else
            return false
        end
    else
        return false
    end
end

function _lint_dict(ps::ParseState, x::EXPR)
    # paramaterised case
    if x.args[1] isa EXPR && x.args[1].head == CURLY
        # expect 2 parameters (+ :Dict)
        if length(x.args[1].args) != 3
            push!(ps.diagnostics, Hint{Hints.DictParaMisSpec}(ps.nt.startbyte - x.span + (0:x[1].span)))
        end
    else
    end
    # Handle generators
    if length(x.args) > 1 
        if x.args[2] isa EXPR && x.args[2].head == GENERATOR
            gen = x.args[2]
            if gen.args[1].head isa OPERATOR{1} && !(gen.args[1].head isa OPERATOR{1, Tokens.PAIR_ARROW})
                push!(ps.diagnostics, Hint{Hints.DictGenAssignment}(ps.nt.startbyte - x.span + (0:x.span)))
            end
        # Lint items
        else
            locstart = ps.nt.startbyte - x.span + x.args[1].span + first(x.punctuation).span
            for (i, a) in enumerate(x.args[2:end])
                # non pair arrow assignment
                if a isa EXPR && a.head isa OPERATOR{1} && !(a.head isa OPERATOR{1, Tokens.PAIR_ARROW})
                    push!(ps.diagnostics, Hint{Hints.DictGenAssignment}(locstart + (0:a.span)))
                end
                locstart += a.span + x.punctuation[i + 1].span
            end
        end
    end
end