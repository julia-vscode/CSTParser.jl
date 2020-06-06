function is_func_call(x::EXPR)
    if isoperator(x.head)
        if length(x.args) == 2
            return is_decl(x.head) && is_func_call(x.args[1])
        elseif length(x.args) == 1
            return !(is_exor(x.head) || is_decl(x.head))
        end
    elseif x.head === :Call
        return true
    elseif x.head === :Where || isbracketed(x)
        return is_func_call(x.args[1])
    else
        return false
    end
end

is_assignment(x::EXPR) = isoperator(x.head) && valof(x.head) == "="

# OPERATOR
is_approx(x::EXPR) = isoperator(x) && valof(x) == "~"
is_exor(x) = isoperator(x) && valof(x) == "\$"
is_decl(x) = isoperator(x) && valof(x) == "::"
is_issubt(x) = isoperator(x) && valof(x) == "<:"
is_issupt(x) = isoperator(x) && valof(x) == ":>"
is_and(x) = isoperator(x) && valof(x) == "&"
is_not(x) = isoperator(x) && valof(x) == "!"
is_plus(x) = isoperator(x) && valof(x) == "+"
is_minus(x) = isoperator(x) && valof(x) == "-"
is_star(x) = isoperator(x) && valof(x) == "*"
is_eq(x) = isoperator(x) && valof(x) == "="
is_dot(x) = isoperator(x) && valof(x) == "."
is_ddot(x) = isoperator(x) && valof(x) == ".."
is_dddot(x) = isoperator(x) && valof(x) == "..."
is_pairarrow(x) = isoperator(x) && valof(x) == "=>"
is_in(x) = isoperator(x) && valof(x) == "in"
is_elof(x) = isoperator(x) && valof(x) == "∈"
is_colon(x) = isoperator(x) && valof(x) == ":"
is_prime(x) = isoperator(x) && valof(x) == "'"
is_cond(x) = isoperator(x) && valof(x) == "?"
is_where(x) = isoperator(x) && valof(x) == "where"
is_anon_func(x) = isoperator(x) && valof(x) == "->"

is_comma(x) = headof(x) === :COMMA
is_lparen(x) = headof(x) === :LPAREN
is_rparen(x) = headof(x) === :Rparen
is_lbrace(x) = headof(x) === :LBRACE
is_rbrace(x) = headof(x) === :RBRACE
is_lsquare(x) = headof(x) === :LSQUARE
is_rsquare(x) = headof(x) === :RSQUARE

# KEYWORD
is_if(x) = iskeyword(x) && headof(x) === :IF
is_import(x) = iskeyword(x) && headof(x) === :IMPORT


# Literals
is_lit_string(x) = kindof(x) === Tokens.STRING || kindof(x) === Tokens.TRIPLE_STRING

issubtypedecl(x::EXPR) = isoperator(x.head) && valof(x.head) == "<:"

rem_subtype(x::EXPR) = issubtypedecl(x) ? x.args[1] : x
rem_decl(x::EXPR) = isdeclaration(x) ? x.args[1] : x
rem_curly(x::EXPR) = headof(x) === :Curly ? x.args[1] : x
rem_call(x::EXPR) = headof(x) === :Call ? x.args[1] : x
rem_where(x::EXPR) = iswherecall(x) ? x.args[1] : x
rem_wheres(x::EXPR) = iswherecall(x) ? rem_wheres(x.args[1]) : x
rem_where_subtype(x::EXPR) = (iswherecall(x) || issubtypedecl(x)) ? x.args[1] : x
rem_where_decl(x::EXPR) = (iswherecall(x) || isdeclaration(x)) ? x.args[1] : x
rem_invis(x::EXPR) = isbracketed(x) ? rem_invis(x.args[1]) : x
rem_dddot(x::EXPR) = is_splat(x) ? x.args[1] : x
const rem_splat = rem_dddot
rem_kw(x::EXPR) = headof(x) === :Kw ? x.args[1] : x

is_some_call(x) = headof(x) === :Call || isunarycall(x)
is_eventually_some_call(x) = is_some_call(x) || ((isdeclaration(x) || iswherecall(x)) && is_eventually_some_call(x.args[1]))

defines_function(x::EXPR) = headof(x) === :Function || (is_assignment(x) && is_eventually_some_call(x.args[1]))
defines_macro(x) = headof(x) == :Macro
defines_datatype(x) = defines_struct(x) || defines_abstract(x) || defines_primitive(x)
defines_struct(x) = headof(x) === :Struct
defines_mutable(x) = defines_struct(x) && x.args[1].head == :TRUE
defines_abstract(x) = headof(x) === :Abstract
defines_primitive(x) = headof(x) === :Primitive
defines_module(x) = headof(x) === :Module
defines_anon_function(x) = isoperator(x.head) && valof(x.head) == "->"

has_sig(x::EXPR) = defines_datatype(x) || defines_function(x) || defines_macro(x) || defines_anon_function(x)

"""
    get_sig(x)

Returns the full signature of function, macro and datatype definitions.
Should only be called when has_sig(x) == true.
"""
function get_sig(x::EXPR)
    if headof(x) isa EXPR # headof(headof(x)) === :OPERATOR valof(headof(x)) == "="
        return x.args[1]
    elseif headof(x) === :Struct || headof(x) === :Mutable 
        return x.args[2]
    elseif  headof(x) === :Abstract || headof(x) === :Primitive || headof(x) === :Function || headof(x) === :Macro
        return x.args[1]
    end
end

function get_name(x::EXPR)
    if defines_datatype(x)
        sig = get_sig(x)
        sig = rem_subtype(sig)
        sig = rem_wheres(sig)
        sig = rem_subtype(sig)
        sig = rem_curly(sig)
    elseif defines_module(x)
        sig = x.args[2]
    elseif defines_function(x) || defines_macro(x)
        sig = get_sig(x)
        sig = rem_wheres(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        if isbinarycall(sig) && is_dot(sig.args[2])
            if length(sig.args) > 2 && sig.args[3].args isa Vector{EXPR} && length(sig.args[3].args) > 0
                sig = sig.args[3].args[1]
            end
        end
        return sig
    elseif isbinarycall(x)
        length(x.args) < 2 && return x
        if is_dot(x.args[2])
            if length(x.args) > 2 && headof(x.args[3]) === :Quotenode && x.args[3].args isa Vector{EXPR} && length(x.args[3].args) > 0
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
