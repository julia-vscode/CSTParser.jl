function parse_kw(ps::ParseState, ::Type{Val{Tokens.FUNCTION}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    # signature

    if isoperator(ps.nt.kind) && ps.nt.kind != Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        start1 = ps.nt.startbyte
        next(ps)
        op = OPERATOR(ps)
        next(ps)
        if issyntaxunarycall(op)
            sig = EXPR{UnarySyntaxOpCall}(EXPR[op, INSTANCE(ps)], 0, Variable[], "")
        else
            sig = EXPR{Call}(EXPR[op, INSTANCE(ps)], 0, Variable[], "")
        end
        @catcherror ps startbyte @default ps @closer ps paren parse_comma_sep(ps, sig)
        next(ps)
        push!(sig.args, INSTANCE(ps))
        sig.span = ps.nt.startbyte - start1
        @default ps @closer ps inwhere @closer ps ws @closer ps block while !closer(ps)
            @catcherror ps startbyte sig = parse_compound(ps, sig)
        end
    else
        @catcherror ps startbyte sig = @default ps @closer ps inwhere @closer ps block @closer ps ws parse_expression(ps)
    end
    
    while ps.nt.kind == Tokens.WHERE
        @catcherror ps startbyte sig = @default ps @closer ps inwhere @closer ps block @closer ps ws parse_compound(ps, sig)
    end

    if sig isa EXPR{InvisBrackets} && !(sig.args[2] isa EXPR{TupleH})
        sig = EXPR{TupleH}(sig.args, sig.span, Variable[], "")
    end

    # _lint_func_sig(ps, sig, ps.nt.startbyte + (-sig.span:0))
    block = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps @scope ps Scope{Tokens.FUNCTION} parse_block(ps, block, start_col)
    
    # fname0 = _get_fname(sig)
    # fname = fname0 isa IDENTIFIER ? fname0.val : :noname
    # _lint_func_body(ps, fname, block, ps.nt.startbyte - block.span)

    # Construction
    if isempty(block.args)
        if sig isa EXPR{Call} || sig isa EXPR{BinarySyntaxOpCall} && !(sig.args[1] isa EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}})
            args = EXPR[sig, block]
        else
            args = EXPR[sig]
        end
    else
        args = EXPR[sig, block]
    end
    
    next(ps)
    
    ret = EXPR{FunctionDef}(EXPR[kw], ps.nt.startbyte - startbyte, Variable[], "")
    for a in args
        push!(ret.args, a)
    end
    push!(ret.args, INSTANCE(ps))

    ret.defs = [Variable(function_name(sig), :Function, ret)]
    return ret
end

"""
    parse_call(ps, ret)

Parses a function call. Expects to start before the opening parentheses and is passed the expression declaring the function name, `ret`.
"""
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}})
    startbyte = ps.t.startbyte
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}})
    startbyte = ps.t.startbyte
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{TimesOp,Tokens.AND}
    startbyte = ps.t.startbyte
    arg = @precedence ps 20 parse_expression(ps)
    ret = EXPR{UnarySyntaxOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    return ret
end
function parse_call(ps::ParseState, ret::EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}})
    startbyte = ps.t.startbyte
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(EXPR[ret; arg.args], ret.span + arg.span, Variable[], "")
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false}})
    startbyte = ps.t.startbyte
    arg = @precedence ps 13 parse_expression(ps)
    ret = EXPR{Call}(EXPR[ret; arg.args], ret.span + arg.span, Variable[], "")
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{20,Tokens.NOT}
    startbyte = ps.t.startbyte
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], ret.span + arg.span, Variable[], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{PlusOp,Tokens.PLUS}
    startbyte = ps.t.startbyte
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], ret.span + arg.span, Variable[], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret::EXPR{OP}) where OP <: OPERATOR{PlusOp,Tokens.MINUS}
    startbyte = ps.t.startbyte
    arg = @precedence ps 13 parse_expression(ps)
    if arg isa EXPR{TupleH}
        ret = EXPR{Call}(EXPR[ret; arg.args], ret.span + arg.span, Variable[], "")
    else
        ret = EXPR{UnaryOpCall}(EXPR[ret, arg], ret.span + arg.span, Variable[], "")
    end
    return ret
end

function parse_call(ps::ParseState, ret)
    startbyte = ps.t.startbyte
    
    next(ps)
    ret = EXPR{Call}(EXPR[ret, INSTANCE(ps)], ret.span - ps.t.startbyte, Variable[], "")
    format_lbracket(ps)
    @default ps @closer ps paren parse_comma_sep(ps, ret)
    next(ps)
    push!(ret.args, INSTANCE(ps))
    format_rbracket(ps)
    ret.span += ps.nt.startbyte
    
    # if length(ret.args) > 0 && ismacro(ret.args[1])
    #     ret.head = MACROCALL
    # end
    # if ret.head isa HEAD{Tokens.CCALL} && length(ret.args) > 1 && ret.args[2] isa IDENTIFIER && (ret.args[2].val == :stdcall || ret.args[2].val == :fastcall || ret.args[2].val == :cdecl || ret.args[2].val == :thiscall)
    #     arg = splice!(ret.args, 2)
    #     push!(ret.args, EXPR(arg, [], arg.span))
    # end

    # Linting
    # if (ret.args[1] isa IDENTIFIER && ret.args[1].val == :Dict) || (ret.args[1] isa EXPR && ret.args[1].head == CURLY && ret.args[1].args[1] isa IDENTIFIER && ret.args[1].args[1].val == :Dict)
    #     _lint_dict(ps, ret)
    # end
    # _check_dep_call(ps, ret)

    # if fname isa IDENTIFIER && fname.val in keys(deprecated_symbols)
    #     push!(ps.diagnostics, Diagnostic{Diagnostics.Deprecation}(ps.nt.startbyte - ret.span + (0:(fname.span))))
    # end
    return ret
end


function parse_comma_sep(ps::ParseState, ret::EXPR, kw = true, block = false, formatcomma = true)
    startbyte = ps.nt.startbyte

    @catcherror ps startbyte @nocloser ps inwhere @noscope ps @nocloser ps newline @closer ps comma while !closer(ps)
        a = parse_expression(ps)
        if kw && !ps.closer.brace && a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
            a = EXPR{Kw}(a.args, a.span, Variable[], "")
        end
        push!(ret.args, a)
        if ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(ret.args, INSTANCE(ps))
            if formatcomma
                format_comma(ps)
            else
                format_no_rws(ps)
            end
        end
        if ps.ws.kind == SemiColonWS
            break
        end
    end

    if ps.ws.kind == SemiColonWS
        if block
            body = EXPR{Block}(EXPR[pop!(ret.args)], 0, Variable[], "")
            body.span = body.args[1].span
            @nocloser ps newline @closer ps comma while @nocloser ps semicolon !closer(ps)
                @catcherror ps startbyte a = parse_expression(ps)
                push!(body.args, a)
                body.span += a.span
            end
            push!(ret.args, body)
            return body
        else
            ps.nt.kind == Tokens.RPAREN && return 
            paras = EXPR{Parameters}(EXPR[], -ps.nt.startbyte, Variable[], "")
            @nocloser ps inwhere @nocloser ps newline @nocloser ps semicolon @closer ps comma while !closer(ps)
                @catcherror ps startbyte a = parse_expression(ps)
                if kw && !ps.closer.brace && a isa EXPR{BinarySyntaxOpCall} && a.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
                    a = EXPR{Kw}(a.args, a.span, Variable[], "")
                end
                push!(paras.args, a)
                if ps.nt.kind == Tokens.COMMA
                    next(ps)
                    push!(paras.args, INSTANCE(ps))
                    format_comma(ps)
                end
            end
            paras.span += ps.nt.startbyte
            push!(ret.args, paras)
        end
    end
end


# Iterators


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
function _lint_func_sig(ps::ParseState, sig::EXPR{IDENTIFIER}, loc) end
    
function _lint_func_sig(ps::ParseState, sig::EXPR, loc)
    if sig isa EXPR{BinarySyntaxOpCall} && (sig.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || sig.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}})
        return _lint_func_sig(ps, sig.args[1], loc)
    end
    fname = _get_fname(sig)
    # use where syntax
    if sig isa EXPR{Call} && sig.args[1] isa EXPR{Curly} 
        push!(ps.diagnostics, Diagnostic{Diagnostics.parameterisedDeprecation}((first(loc) + sig.args[1].args[1].span):(first(loc) + sig.args[1].span), []))
        
        trailingws = last(sig.args) isa EXPR{PUNCTUATION{Tokens.RPAREN}} ? last(sig.args).span - 1 : 0
        loc1 = first(loc) + sig.span - trailingws
        push!(last(ps.diagnostics).actions, Diagnostics.TextEdit((loc1):(loc1), string(" where {", join((Expr(t) for t in sig.args[1].args[2:end]), ","), "}")))
        push!(last(ps.diagnostics).actions, Diagnostics.TextEdit((first(loc) + sig.args[1].args[1].span):(first(loc) + sig.args[1].span), ""))
    end
    
    # format_funcname(ps, function_name(sig), sig.span)
    args = Tuple{Symbol,Any}[]
    nargs = sum(typeof(a).parameters[1].name.name==:PUNCTUATION for a in sig.args) - 1
    firstkw  = nargs + 1
    i = 1
    for arg in sig.args[2:end]
        if !(arg isa EXPR{P} where P <: PUNCTUATION)
            if arg isa EXPR{BinarySyntaxOpCall} && arg.args[1] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}}
                #unhandled ::Type argument
                i += 1
                continue
            elseif arg isa EXPR{Parameters}
                i1 = 1
                for arg1 in arg.args
                    if !(arg1 isa EXPR{P} where P <: PUNCTUATION)
                        _lint_arg(ps, arg1, args, i + i1 - 1, fname, nargs, i - 1, loc)
                        i1 += 1
                    end
                end
            else
                _lint_arg(ps, arg, args, i, fname, nargs, firstkw, loc)
            end
            i += 1
        end
    end
    sig.defs = (a -> Variable(a[1], a[2], sig)).(args)
end
    
function _lint_arg(ps::ParseState, arg, args, i, fname, nargs, firstkw, loc)
    a = _arg_id(arg)
    t = get_t(arg)
    !(a isa EXPR{IDENTIFIER}) && return
    # if !(a.val in args)
    if !any(a.val == aa[1] for aa in args)
        push!(args, (a.val, t))
    else 
        push!(ps.diagnostics, Diagnostic{Diagnostics.DuplicateArgumentName}(loc, []))
    end
    if a.val == Expr(fname)
        push!(ps.diagnostics, Diagnostic{Diagnostics.ArgumentFunctionNameConflict}(loc, []))
    end
    if arg isa EXPR{UnarySyntaxOpCall} && arg.args[2] isa EXPR{OPERATOR{0,Tokens.DDDOT,false}} && i != nargs
        push!(ps.diagnostics, Diagnostic{Diagnostics.SlurpingPosition}(loc, []))
    end
    if arg isa EXPR{Kw} && i < firstkw
        firstkw = i
    end
    if !(arg isa EXPR{Kw}) && i > firstkw
        push!(ps.diagnostics, Diagnostic{Diagnostics.KWPosition}(loc, []))
    end
    # Check 
end

# make this traverse EXPR that contribute scope
# function _lint_func_body(ps::ParseState, fname, body, loc)
#     for a in body.args
#         if a isa EXPR
#             for d in a.defs
#                 if d.id == fname
#                     push!(ps.diagnostics, Diagnostic{Diagnostics.AssignsToFuncName}(loc + (0:a.span), []))
#                 end
#             end
#         end
#         if contributes_scope(a)
#             _lint_func_body(ps::ParseState, fname, a, loc)
#         end
#         loc += a.span
#     end
# end




# NEEDS FIX
_arg_id(x) = x
_arg_id(x::EXPR{IDENTIFIER}) = x
_arg_id(x::EXPR{Quotenode}) = x.val
_arg_id(x::EXPR{Curly}) = _arg_id(x.args[1])
_arg_id(x::EXPR{Kw}) = _arg_id(x.args[1])


function _arg_id(x::EXPR{UnarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{7,Tokens.DDDOT,false}}
        return _arg_id(x.args[1])
    else
        return x
    end
end

function _arg_id(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        return _arg_id(x.args[1])
    else
        return x
    end
end



function _sig_params(x, p = [])
    if x isa EXPR{Curly}
        for a in x.args[2:end]
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                push!(p, get_id(a))
            end
        end
    end
    return p
end


_get_fname(sig::EXPR{IDENTIFIER}) = sig
_get_fname(sig::EXPR{Tuple}) = NOTHING
_get_fname(sig::EXPR{BinarySyntaxOpCall}) = sig.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} || sig.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}} ? get_id(sig.args[1].args[1]) : get_id(sig.args[1])
_get_fname(sig) = get_id(sig.args[1])

# function declares_function(x::EXPR)
#     if x isa EXPR
#         if x.head isa KEYWORD{Tokens.FUNCTION}
#             return true
#         elseif x.head isa OPERATOR{AssignmentOp,Tokens.EQ} && x.args[1] isa EXPR && x.args[1].head == CALL
#             return true
#         else
#             return false
#         end
#     else
#         return false
#     end
# end

function_name(sig::EXPR{Call}) = function_name(sig.args[1])
function_name(sig::EXPR{Curly}) = function_name(sig.args[1])
function_name(sig::EXPR{BinarySyntaxOpCall}) = function_name(sig.args[2])
function_name(sig::EXPR{Quotenode}) = function_name(sig.args[1])
function_name(sig::EXPR{IDENTIFIER}) = Symbol(sig.val)
function_name(sig::EXPR{OPERATOR{P,K,dot}}) where {P,K,dot} = UNICODE_OPS_REVERSE[K]
function_name(sig) = :unknown




declares_function(x) = false
declares_function(x::EXPR{FunctionDef}) = true
declares_function(x::EXPR{BinarySyntaxOpCall}) = x.args[2] isa OPERATOR{AssignmentOp,Tokens.EQ,false} && x.args[1] isa EXPR{Call}



# function _lint_dict(ps::ParseState, x::EXPR)
#     # paramaterised case
#     if x.args[1] isa EXPR && x.args[1].head == CURLY
#         # expect 2 parameters (+ :Dict)
#         if length(x.args[1].args) != 3
#             push!(ps.diagnostics, Diagnostic{Diagnostics.DictParaMisSpec}(ps.nt.startbyte - x.span + (0:x[1].span), []))
#         end
#     end
#     # Handle generators
#     if length(x.args) > 1 
#         if x.args[2] isa EXPR && x.args[2].head == GENERATOR
#             gen = x.args[2]
#             if gen.args[1].head isa OPERATOR{AssignmentOp} && !(gen.args[1].head isa OPERATOR{AssignmentOp,Tokens.PAIR_ARROW})
#                 push!(ps.diagnostics, Diagnostic{Diagnostics.DictGenAssignment}(ps.nt.startbyte - x.span + (0:x.span), []))
#             end
#         # Lint items
#         else
#             locstart = ps.nt.startbyte - x.span + x.args[1].span + first(x.punctuation).span
#             for (i, a) in enumerate(x.args[2:end])
#                 # non pair arrow assignment
#                 if a isa EXPR && a.head isa OPERATOR{AssignmentOp} && !(a.head isa OPERATOR{AssignmentOp,Tokens.PAIR_ARROW})
#                     push!(ps.diagnostics, Diagnostic{Diagnostics.DictGenAssignment}(locstart + (0:a.span), []))
#                 end
#                 locstart += a.span + x.punctuation[i + 1].span
#             end
#         end
#     end
# end
