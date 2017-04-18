# Macro expressions :
#     definitions
#     calls (ws and tuple form)

function parse_kw(ps::ParseState, ::Type{Val{Tokens.MACRO}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4
    kw = INSTANCE(ps)
    @catcherror ps startbyte sig = @closer ps block @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)

    next(ps)
    ret = EXPR(kw, SyntaxNode[sig, block], ps.nt.startbyte - startbyte, INSTANCE[INSTANCE(ps)])
    ret.defs =  [Variable(function_name(sig), :Macro, ret)]
    return ret
end

"""
    parse_macrocall(ps)

Parses a macro call. Expects to start on the `@`.
"""
function parse_macrocall(ps::ParseState)
    startbyte = ps.t.startbyte
    next(ps)
    mname = IDENTIFIER(ps.nt.startbyte - ps.lt.startbyte, string("@", ps.t.val))
    # Handle cases with @ at start of dotted expressions
    if ps.nt.kind == Tokens.DOT && isempty(ps.ws)
        while ps.nt.kind == Tokens.DOT
            next(ps)
            op = INSTANCE(ps)
            if ps.nt.kind != Tokens.IDENTIFIER
                return ERROR{InvalidMacroName}(startbyte:ps.nt.startbyte, mname)
                
            end
            next(ps)
            nextarg = INSTANCE(ps)
            mname = EXPR(op, [mname, QUOTENODE(nextarg)], mname.span + op.span + nextarg.span)
        end
    end
    ret = EXPR(MACROCALL, [mname], 0)

    if ps.nt.kind == Tokens.COMMA
        ret.span = ps.nt.startbyte - startbyte
        return ret
    end
    if isempty(ps.ws) && ps.nt.kind == Tokens.LPAREN
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
        @catcherror ps startbyte args = @default ps @nocloser ps newline @closer ps paren parse_list(ps, ret.punctuation)
        append!(ret.args, args)
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
    else
        insquare = ps.closer.insquare
        @default ps while !closer(ps)
            @catcherror ps startbyte a = @closer ps inmacro @closer ps ws parse_expression(ps)
            push!(ret.args, a)
            if insquare && ps.nt.kind == Tokens.FOR
                break
            end
        end
    end
    ret.span = ps.nt.startbyte - startbyte
    return ret
end

function _start_macrocall(x::EXPR)
    return Iterator{:macrocall}(1, length(x.args) + length(x.punctuation))
end

function next(x::EXPR, s::Iterator{:macrocall})
    if isempty(x.punctuation)
        return x.args[s.i], +s
    else
        if s.i == s.n
            return last(x.punctuation), +s
        elseif isodd(s.i)
            return x.args[div(s.i + 1, 2)], +s
        else
            return x.punctuation[div(s.i, 2)], +s
        end
    end
end

ismacro(x) = false
ismacro(x::LITERAL{Tokens.MACRO}) = true
ismacro(x::QUOTENODE) = ismacro(x.val)
function ismacro(x::EXPR)
    if x.head isa OPERATOR{15, Tokens.DOT}
        return ismacro(x.args[2])
    else
        return false
    end
end


function next(x::EXPR, s::Iterator{:macro})
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