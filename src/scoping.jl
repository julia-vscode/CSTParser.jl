is_func_call(x) = false
is_func_call(x::EXPR) = x.head == CALL

"""
    get_id(x)

Get the IDENTIFIER name of a variable, possibly in the presence of 
type declaration operators.
"""
get_id{T<:INSTANCE}(x::T) = x

function get_id(x::EXPR)
    if x.head isa OPERATOR{6,Tokens.ISSUBTYPE} || x.head isa OPERATOR{14, Tokens.DECLARATION} || x.head == CURLY
        return get_id(x.args[1])
    else
        return x
    end
end


"""
    get_t(x)

Basic inference in the presence of type declarations.
"""
get_t{T<:INSTANCE}(x::T) = :Any

function get_t(x::EXPR)
    if x.head isa OPERATOR{14, Tokens.DECLARATION}
        return x.args[2]
    else
        return :Any
    end
end

function func_sig(x::EXPR)
    name = x.args[1]
    args = x.args[2:end]
    if name isa EXPR && name.head == CURLY
        params = name.args[2]
        name = name.args[1]
    end
    if name isa EXPR && name.head isa OPERATOR{15,Tokens.DOT}
        mod = name.args[1]
        name = name.args[2]
    end
    if name isa QUOTENODE
        name = name.val
    end
end

"""
    _track_assignment(ps, x, val, defs = [])

When applied to the lhs of an assignment returns a vector of the 
newly defined variables.
"""
function _track_assignment(ps::ParseState, x, val, defs = [])
    if x isa IDENTIFIER
        push!(defs, Variable(Expr(x), :Any, val))
    elseif x isa EXPR && x.head == TUPLE
        for a in x.args
            _track_assignment(ps, a, val, defs)
        end
    end
    return defs
end

function get_symbols(x, offset = 0, symbols = []) end
function get_symbols(x::EXPR, offset = 0, symbols = [])
    for a in x
        if a isa EXPR
            if !isempty(a.defs)
                for v in a.defs
                    push!(symbols, (v, offset + (1:a.span)))
                end
            end
            if contributes_scope(a)
                get_symbols(a, offset, symbols)
            end
            if a.head isa KEYWORD{Tokens.MODULE} || a.head isa KEYWORD{Tokens.MODULE}
                m_scope = get_symbols(a[3])
                offset2 = offset + a[1].span + a[2].span
                for mv in m_scope
                    push!(symbols, (Variable(Expr(:(.), a.defs[1].id, QuoteNode(mv[1].id)), mv[1].t, mv[1].val), mv[2] + offset2))
                    
                end
            end
        end
        offset += a.span
    end
    return symbols
end



function _get_includes(x, files = []) end

function _get_includes(x::EXPR, files = [])
    no_iter(x) && return files

    if x.head == CALL && x[1] isa IDENTIFIER && x[1].val == :include
        if x[3] isa LITERAL{Tokens.STRING} || x[3] isa LITERAL{Tokens.TRIPLE_STRING}
            push!(files, x.args[2].val)
        end
    else
        for a in x
            if a isa EXPR && !(a.head isa KEYWORD{Tokens.FUNCTION}) && !(a.head isa KEYWORD{Tokens.MACRO})
                _get_includes(a, files)
            end
        end
    end
    return files
end

function _find_scope(x::EXPR, n, path, ind, offsets, scope)
    # No scoping/iteration for STRING 
    if x.head == STRING
        return x
    elseif x.head isa KEYWORD{Tokens.USING} || x.head isa KEYWORD{Tokens.IMPORT} || x.head isa KEYWORD{Tokens.IMPORTALL} || (x.head == TOPLEVEL && all(x.args[i] isa EXPR && (x.args[i].head isa KEYWORD{Tokens.IMPORT} || x.args[i].head isa KEYWORD{Tokens.IMPORTALL} || x.args[i].head isa KEYWORD{Tokens.USING}) for i = 1:length(x.args)))
        for d in x.defs
            unshift!(scope, (d, sum(offsets) + (1:x.span)))
        end
        return x
    end
    offset = 0
    if n > x.span
        return NOTHING
    end
    push!(path, x)
    for (i, a) in enumerate(x)
        if n > offset + a.span
            get_scope(a, sum(offsets) + offset, scope)
            offset += a.span
        else
            if a isa EXPR
                for d in a.defs
                    push!(scope, (d, sum(offsets) + offset + (1:a.span)))
                end
            end

            push!(ind, i)
            push!(offsets, offset)
            # If toplevel/module get scope for rest of block
            if x.head == BLOCK && length(path) > 1 && path[end - 1] isa EXPR && (path[end - 1].head == TOPLEVEL || path[end - 1].head isa KEYWORD{Tokens.MODULE} || path[end - 1].head isa KEYWORD{Tokens.BAREMODULE})
                offset1 = sum(offsets) + offset
                for j = i + 1:length(x)
                    get_scope(x[j], offset1, scope)
                    offset1 += x[j].span
                end
            end
            return _find_scope(a, n - offset, path, ind, offsets, scope)
        end
    end
end

_find_scope(x::Union{QUOTENODE,INSTANCE,ERROR}, n, path, ind, offsets, scope) = x

function find_scope(x::EXPR, n::Int)
    path = []
    ind = Int[]
    offsets = Int[]
    scope = Tuple{Variable, UnitRange}[]
    y = _find_scope(x, n, path, ind, offsets, scope)
    return y, path, ind, offsets, scope
end

function get_scope(x, offset, scope) end

function get_scope(x::EXPR, offset, scope)
    for d in x.defs
        push!(scope, (d, offset + (1:x.span)))
    end
    if contributes_scope(x)
        for a in x
            get_scope(a, offset, scope)
        end
    end
end


contributes_scope(x) = false
function contributes_scope(x::EXPR)
    x.head isa KEYWORD{Tokens.BLOCK} ||
    x.head isa KEYWORD{Tokens.CONST} ||
    x.head isa KEYWORD{Tokens.GLOBAL} || 
    x.head isa KEYWORD{Tokens.IF} ||
    x.head isa KEYWORD{Tokens.LOCAL} ||
    x.head isa HEAD{Tokens.MACROCALL}
end





find_scope(x::ERROR, n::Int) = ERROR, [], [], [], [], []
