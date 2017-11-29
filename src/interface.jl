is_func_call(x) = false
is_func_call(x::EXPR) = false
is_func_call(x::EXPR{Call}) = true
is_func_call(x::UnaryOpCall) = true
function is_func_call(x::BinarySyntaxOpCall)
    if is_decl(x.op)
        return is_func_call(x.arg1)
    else
        return false
    end
end
function is_func_call(x::WhereOpCall)
    return is_func_call(x.arg1)
end

# OPERATOR
is_exor(x) = x isa OPERATOR && x.kind == Tokens.EX_OR && x.dot == false
is_decl(x) = x isa OPERATOR && x.kind == Tokens.DECLARATION
is_issubt(x) = x isa OPERATOR && x.kind == Tokens.ISSUBTYPE
is_issupt(x) = x isa OPERATOR && x.kind == Tokens.ISSUPERTYPE
is_and(x) = x isa OPERATOR && x.kind == Tokens.AND && x.dot == false
is_not(x) = x isa OPERATOR && x.kind == Tokens.NOT && x.dot == false
is_plus(x) = x isa OPERATOR && x.kind == Tokens.PLUS && x.dot == false
is_minus(x) = x isa OPERATOR && x.kind == Tokens.MINUS && x.dot == false
is_star(x) = x isa OPERATOR && x.kind == Tokens.STAR && x.dot == false
is_eq(x) = x isa OPERATOR && x.kind == Tokens.EQ && x.dot == false
is_dot(x) = x isa OPERATOR && x.kind == Tokens.DOT
is_ddot(x) = x isa OPERATOR && x.kind == Tokens.DDOT
is_dddot(x) = x isa OPERATOR && x.kind == Tokens.DDDOT
is_pairarrow(x) = x isa OPERATOR && x.kind == Tokens.PAIR_ARROW && x.dot == false
is_in(x) = x isa OPERATOR && x.kind == Tokens.IN && x.dot == false
is_elof(x) = x isa OPERATOR && x.kind == Tokens.ELEMENT_OF && x.dot == false
is_colon(x) = x isa OPERATOR && x.kind == Tokens.COLON
is_prime(x) = x isa OPERATOR && x.kind == Tokens.PRIME
is_cond(x) = x isa OPERATOR && x.kind == Tokens.CONDITIONAL
is_where(x) = x isa OPERATOR && x.kind == Tokens.WHERE
is_anon_func(x) = x isa OPERATOR && x.kind == Tokens.ANON_FUNC

# PUNCTUATION
is_comma(x) = x isa PUNCTUATION && x.kind == Tokens.COMMA
is_lparen(x) = x isa PUNCTUATION && x.kind == Tokens.LPAREN
is_rparen(x) = x isa PUNCTUATION && x.kind == Tokens.RPAREN
is_lbrace(x) = x isa PUNCTUATION && x.kind == Tokens.LBRACE
is_rbrace(x) = x isa PUNCTUATION && x.kind == Tokens.RBRACE
is_lsquare(x) = x isa PUNCTUATION && x.kind == Tokens.LSQUARE
is_rsquare(x) = x isa PUNCTUATION && x.kind == Tokens.RSQUARE

# KEYWORD
is_if(x) = x isa KEYWORD && x.kind == Tokens.IF
is_module(x) = x isa KEYWORD && x.kind == Tokens.MODULE
is_import(x) = x isa KEYWORD && x.kind == Tokens.IMPORT
is_importall(x) = x isa KEYWORD && x.kind == Tokens.IMPORTALL


_arg_id(x) = x
_arg_id(x::IDENTIFIER) = x
_arg_id(x::EXPR{Quotenode}) = x.args[1]
_arg_id(x::EXPR{Curly}) = _arg_id(x.args[1])
_arg_id(x::EXPR{Kw}) = _arg_id(x.args[1])


function _arg_id(x::UnarySyntaxOpCall)
    if is_dddot(x.arg2)
        return _arg_id(x.arg1)
    else
        return x
    end
end

function _arg_id(x::BinarySyntaxOpCall)
    if is_decl(x.op)
        return _arg_id(x.arg1)
    else
        return x
    end
end
function _arg_id(x::WhereOpCall)
    return _arg_id(x.arg1)
end


_get_fparams(x, args = Symbol[]) = args

function _get_fparams(x::EXPR{Call}, args = Symbol[])
    if x.args[1] isa EXPR{Curly}
        _get_fparams(x.args[1], args)
    end
    unique(args)
end

function _get_fparams(x::EXPR{Curly}, args = Symbol[])
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa IDENTIFIER
                push!(args, Expr(a))
            elseif a isa BinarySyntaxOpCall && is_issubt(a.op)
                push!(args, Expr(a).args[1])
            end
        end
    end
    unique(args)
end

function _get_fparams(x::WhereOpCall, args = Symbol[])
    if x.arg1 isa WhereOpCall
        _get_fparams(x.arg1, args)
    end
    for i = 1:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            if a isa IDENTIFIER
                push!(args, Expr(a))
            elseif a isa BinarySyntaxOpCall && is_issubt(a.op) && a.arg1 isa IDENTIFIER
                push!(args, Expr(a.arg1))
            end
        end
    end
    return unique(args)
end


# _get_fname(sig::EXPR{FunctionDef}) = _get_fname(sig.args[2])
# _get_fname(sig::IDENTIFIER) = sig
# _get_fname(sig::EXPR{TupleH}) = NOTHING
# function _get_fname(sig::WhereOpCall)
#     return _get_fname(sig.arg1)
# end
# _get_fname(sig::BinaryOpCall) = sig.op
# function _get_fname(sig::BinarySyntaxOpCall)
#     if is_decl(sig.op)
#         return _get_fname(sig.arg1)
#     else
#         return get_id(sig.arg1)
#     end
# end
# _get_fname(sig) = get_id(sig.args[1])
# _get_fname(sig::UnaryOpCall) = sig.op
# _get_fname(sig::UnarySyntaxOpCall) = sig.arg1 isa OPERATOR ? sig.arg1 : sig.arg2

# _get_fsig(fdecl::EXPR{FunctionDef}) = fdecl.args[2]
# _get_fsig(fdecl::BinarySyntaxOpCall) = fdecl.arg1

function rem_subtype(x)
    if x isa BinarySyntaxOpCall && x.op isa OPERATOR && x.op.kind == Tokens.ISSUBTYPE
        return x.arg1
    else
        return x
    end
end

function rem_decl(x)
    if x isa BinarySyntaxOpCall && is_decl(x.op)
        return x.arg1
    else
        return x
    end
end

function rem_curly(x)
    if x isa EXPR{Curly}
        return x.args[1]
    else
        return x
    end
end

function rem_call(x)
    if x isa EXPR{Call}
        return x.args[1]
    else
        return x
    end
end

function rem_where(x)
    if x isa WhereOpCall
        return x.arg1
    else
        return x
    end
end

function rem_invis(x)
    if x isa EXPR{InvisBrackets}
        return x.args[2]
    else
        return x
    end
end

function rem_dddot(x)
    if x isa UnarySyntaxOpCall && is_dddot(x.arg2)
        return x.arg1
    else
        return x
    end
end

# Definitions
defines_function(x) = false
defines_function(x::EXPR{FunctionDef}) = true
function defines_function(x::BinarySyntaxOpCall)
    if is_eq(x.op)
        sig = x.arg1
        while true
            if sig isa EXPR{Call}
                return true
            elseif sig isa BinarySyntaxOpCall && is_decl(sig.op) || sig isa WhereOpCall
                sig = sig.arg1
            elseif sig isa UnaryOpCall && sig.arg isa BinarySyntaxOpCall && is_decl(sig.arg.op) && sig.arg.arg1 isa EXPR{InvisBrackets}
                return true
            else
                return false
            end
        end
    end
    return false
end

defines_macro(x) = false
defines_macro(x::EXPR{Macro}) = true


function defines_datatype(x)
    defines_struct(x)
end

defines_struct(x) = x isa EXPR{Struct} || defines_mutable(x)
defines_mutable(x) = x isa EXPR{Mutable}
defines_abstract(x) = x isa EXPR{Abstract}
function defines_primitive(x) 
    x isa EXPR{Primitive} || 
    x isa EXPR{Bitstype} # NEEDS FIX: v0.6 dep
end

defines_module(x) = x isa EXPR{ModuleH} || x isa EXPR{BareModule}


function has_sig(x)
    defines_datatype(x) || defines_function(x) || defines_macro(x)
end


"""
    get_sig(x)

Returns the full signature of function, macro and datatype definitions. 
Should only be called when has_sig(x) == true.
"""
get_sig(x::EXPR{Struct}) = x.args[2]
get_sig(x::EXPR{Mutable}) = x.args[3]
get_sig(x::EXPR{Abstract}) = length(x.args) == 4 ? x.args[3] : x.args[2]
get_sig(x::EXPR{T}) where T <: Union{Primitive,Bitstype}  = x.args[3]
get_sig(x::EXPR{FunctionDef}) = x.args[2]

function get_name(x::EXPR{T}) where T <: Union{Struct,Mutable,Abstract,Primitive,Bitstype}
    sig = get_sig(x)
    sig = rem_where(sig)
    sig = rem_subtype(sig)
    sig = rem_curly(sig)
    return sig
end

function get_name(x::EXPR{T}) where T <: Union{ModuleH,BareModule}
    x.args[2]
end

function get_name(sig)
    sig = rem_where(sig)
    sig = rem_decl(sig)
    sig = rem_call(sig)
    sig = rem_curly(sig)
    sig = rem_invis(sig)
    return sig
end

function get_name(x::EXPR{FunctionDef})
    sig = get_sig(x)
    sig = rem_where(sig)
    sig = rem_decl(sig)
    sig = rem_call(sig)
    sig = rem_curly(sig)
    sig = rem_invis(sig)
    return sig
end

function get_name(x::BinarySyntaxOpCall)
    sig = x.arg1
    if sig isa UnaryOpCall
        return sig.op
    end
    sig = rem_where(sig)
    sig = rem_decl(sig)
    sig = rem_call(sig)
    sig = rem_curly(sig)
    sig = rem_invis(sig)
end

function get_arg_name(arg)
    arg = rem_dddot(arg)
    arg = rem_where(arg)
    arg = rem_decl(arg)
    arg = rem_subtype(arg)
    arg = rem_curly(arg)
    arg = rem_invis(arg)
end



function get_arg_type(arg)
    if arg isa BinarySyntaxOpCall && is_decl(arg.op)
        return Expr(arg.arg2)
    else
        return :Any
    end
end

get_body(x::EXPR{ModuleH}) = x.args[3]
get_body(x::EXPR{BareModule}) = x.args[3]
get_body(x::EXPR{If}) = x.args[3]
get_body(x::EXPR{For}) = x.args[3]
get_body(x::EXPR{While}) = x.args[3]
get_body(x::EXPR{FunctionDef}) = x.args[3]
get_body(x::EXPR{Macro}) = x.args[3]
get_body(x::EXPR{Struct}) = x.args[3]
get_body(x::EXPR{Mutable}) = x.args[4]
    

declares_function = defines_function
_get_fname = get_name
_get_fsig = get_sig

