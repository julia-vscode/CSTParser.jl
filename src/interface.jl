function is_func_call(x::EXPR)
    if typof(x) === Call
        return true
    elseif iswherecall(x)
        return is_func_call(x.args[1])
    elseif isbracketed(x)
        return is_func_call(x.args[2])
    elseif isunarycall(x)
        return !(isoperator(x.args[1]) && (kindof(x.args[1]) === Tokens.EX_OR || kindof(x.args[1]) === Tokens.DECLARATION))
    elseif isbinarycall(x)
        if issyntaxcall(x.args[2])
            if is_decl(x.args[2])
                return is_func_call(x.args[1])
            else
                return false
            end
        else
            true
        end
    else
        return false
    end
end

is_assignment(x) = isbinarycall(x) && kindof(x.args[2]) === Tokens.EQ

# OPERATOR
is_exor(x) = isoperator(x) && kindof(x) === Tokens.EX_OR && x.dot == false
is_decl(x) = isoperator(x) && kindof(x) === Tokens.DECLARATION
is_issubt(x) = isoperator(x) && kindof(x) === Tokens.ISSUBTYPE
is_issupt(x) = isoperator(x) && kindof(x) === Tokens.ISSUPERTYPE
is_and(x) = isoperator(x) && kindof(x) === Tokens.AND && x.dot == false
is_not(x) = isoperator(x) && kindof(x) === Tokens.NOT && x.dot == false
is_plus(x) = isoperator(x) && kindof(x) === Tokens.PLUS && x.dot == false
is_minus(x) = isoperator(x) && kindof(x) === Tokens.MINUS && x.dot == false
is_star(x) = isoperator(x) && kindof(x) === Tokens.STAR && x.dot == false
is_eq(x) = isoperator(x) && kindof(x) === Tokens.EQ && x.dot == false
is_dot(x) = isoperator(x) && kindof(x) === Tokens.DOT
is_ddot(x) = isoperator(x) && kindof(x) === Tokens.DDOT
is_dddot(x) = isoperator(x) && kindof(x) === Tokens.DDDOT
is_pairarrow(x) = isoperator(x) && kindof(x) === Tokens.PAIR_ARROW && x.dot == false
is_in(x) = isoperator(x) && kindof(x) === Tokens.IN && x.dot == false
is_elof(x) = isoperator(x) && kindof(x) === Tokens.ELEMENT_OF && x.dot == false
is_colon(x) = isoperator(x) && kindof(x) === Tokens.COLON
is_prime(x) = isoperator(x) && kindof(x) === Tokens.PRIME
is_cond(x) = isoperator(x) && kindof(x) === Tokens.CONDITIONAL
is_where(x) = isoperator(x) && kindof(x) === Tokens.WHERE
is_anon_func(x) = isoperator(x) && kindof(x) === Tokens.ANON_FUNC

is_comma(x) = ispunctuation(x) && kindof(x) === Tokens.COMMA
is_lparen(x) = ispunctuation(x) && kindof(x) === Tokens.LPAREN
is_rparen(x) = ispunctuation(x) && kindof(x) === Tokens.RPAREN
is_lbrace(x) = ispunctuation(x) && kindof(x) === Tokens.LBRACE
is_rbrace(x) = ispunctuation(x) && kindof(x) === Tokens.RBRACE
is_lsquare(x) = ispunctuation(x) && kindof(x) === Tokens.LSQUARE
is_rsquare(x) = ispunctuation(x) && kindof(x) === Tokens.RSQUARE

# KEYWORD
is_if(x) = iskw(x) && kindof(x) === Tokens.IF
is_import(x) = iskw(x) && kindof(x) === Tokens.IMPORT


# Literals
is_lit_string(x) = kindof(x) === Tokens.STRING || kindof(x) === Tokens.TRIPLE_STRING

issubtypedecl(x::EXPR) = isbinarycall(x) && is_issubt(x.args[2])

rem_subtype(x::EXPR) = issubtypedecl(x) ? x[1] : x
rem_decl(x::EXPR) = isdeclaration(x) ? x[1] : x
rem_curly(x::EXPR) = typof(x) === Curly ? x.args[1] : x
rem_call(x::EXPR) = typof(x) === Call ? x[1] : x
rem_where(x::EXPR) = iswherecall(x) ? x[1] : x
rem_wheres(x::EXPR) = iswherecall(x) ? rem_wheres(x[1]) : x
rem_where_subtype(x::EXPR) = (iswherecall(x) || issubtypedecl(x)) ? x[1] : x
rem_where_decl(x::EXPR) = (iswherecall(x) || isdeclaration(x)) ? x[1] : x
rem_invis(x::EXPR) = isbracketed(x) ? rem_invis(x[2]) : x
rem_dddot(x::EXPR) = is_splat(x) ? x[1] : x
const rem_splat = rem_dddot
rem_kw(x::EXPR) = typof(x) === Kw ? x[1] : x

is_some_call(x) = typof(x) === Call || isunarycall(x) || (isbinarycall(x) && !(kindof(x.args[2]) === Tokens.DOT || issyntaxcall(x.args[2])))
is_eventually_some_call(x) = is_some_call(x) || ((isdeclaration(x) || iswherecall(x)) && is_eventually_some_call(x[1]))

defines_function(x::EXPR) = typof(x) === FunctionDef || (is_assignment(x) && is_eventually_some_call(x[1]))
defines_macro(x) = typof(x) == Macro
defines_datatype(x) = defines_struct(x) || defines_abstract(x) || defines_primitive(x)
defines_struct(x) = typof(x) === Struct || defines_mutable(x)
defines_mutable(x) = typof(x) === Mutable
defines_abstract(x) = typof(x) === Abstract
defines_primitive(x) = typof(x) === Primitive
defines_module(x) = typof(x) === ModuleH || typof(x) === BareModule
defines_anon_function(x) = isbinarycall(x) && is_anon_func(x.args[2])

has_sig(x::EXPR) = defines_datatype(x) || defines_function(x) || defines_macro(x) || defines_anon_function(x)

"""
    get_sig(x)

Returns the full signature of function, macro and datatype definitions.
Should only be called when has_sig(x) == true.
"""
function get_sig(x::EXPR)
    if isbinarycall(x)
        return x.args[1]
    elseif typof(x) === Struct || typof(x) === FunctionDef || typof(x) === Macro
        return x.args[2]
    elseif typof(x) === Mutable || typof(x) === Abstract || typof(x) === Primitive
        return x.args[3]
    end
end

function get_name(x::EXPR)
    if typof(x) === Struct || typof(x) === Mutable || typof(x) === Abstract || typof(x) === Primitive
        sig = get_sig(x)
        sig = rem_subtype(sig)
        sig = rem_wheres(sig)
        sig = rem_subtype(sig)
        sig = rem_curly(sig)
    elseif typof(x) === ModuleH || typof(x) === BareModule
        sig = x.args[2]
    elseif typof(x) === FunctionDef || typof(x) === Macro
        sig = get_sig(x)
        sig = rem_wheres(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        if isbinarycall(sig) && kindof(sig.args[2]) === Tokens.DOT
            if length(sig.args) > 2 && sig.args[3].args isa Vector{EXPR} && length(sig.args[3].args) > 0
                sig = sig.args[3].args[1]
            end
        end
        return sig
    elseif isbinarycall(x)
        length(x.args) < 2 && return x
        if kindof(x.args[2]) === Tokens.DOT
            if length(x.args) > 2 && typof(x.args[3]) === Quotenode && x.args[3].args isa Vector{EXPR} && length(x.args[3].args) > 0
                return get_name(x.args[3].args[1])
            else
                return x
            end
        end
        sig = x.args[1]
        if isunarycall(sig)
            return get_name(sig.args[1])
        end
        sig = rem_wheres(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        return get_name(sig)
    else
        sig = x
        if isunarycall(sig)
            sig = sig.args[1]
        end
        sig = rem_wheres(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
    end
end

function get_arg_name(arg::EXPR)
    arg = rem_kw(arg)
    arg = rem_dddot(arg)
    arg = rem_where(arg)
    arg = rem_decl(arg)
    arg = rem_subtype(arg)
    arg = rem_curly(arg)
    arg = rem_invis(arg)
end
