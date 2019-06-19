function is_func_call(x)
    if x.typ === Call
        return true
    elseif x.typ === WhereOpCall
        return is_func_call(x.args[1])
    elseif x.typ === InvisBrackets
        return is_func_call(x.args[2])
    elseif x.typ === UnaryOpCall
        return !(isoperator(x.args[1]) && (x.args[1].kind === Tokens.EX_OR || x.args[1].kind === Tokens.DECLARATION))
    elseif x.typ === BinaryOpCall
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

is_assignment(x) = x.typ === BinaryOpCall && x.args[2].kind === Tokens.EQ

# OPERATOR
is_exor(x) = isoperator(x) && x.kind == Tokens.EX_OR && x.dot == false
is_decl(x) = isoperator(x) && x.kind == Tokens.DECLARATION
is_issubt(x) = isoperator(x) && x.kind == Tokens.ISSUBTYPE
is_issupt(x) = isoperator(x) && x.kind == Tokens.ISSUPERTYPE
is_and(x) = isoperator(x) && x.kind == Tokens.AND && x.dot == false
is_not(x) = isoperator(x) && x.kind == Tokens.NOT && x.dot == false
is_plus(x) = isoperator(x) && x.kind == Tokens.PLUS && x.dot == false
is_minus(x) = isoperator(x) && x.kind == Tokens.MINUS && x.dot == false
is_star(x) = isoperator(x) && x.kind == Tokens.STAR && x.dot == false
is_eq(x) = isoperator(x) && x.kind == Tokens.EQ && x.dot == false
is_dot(x) = isoperator(x) && x.kind == Tokens.DOT
is_ddot(x) = isoperator(x) && x.kind == Tokens.DDOT
is_dddot(x) = isoperator(x) && x.kind == Tokens.DDDOT
is_pairarrow(x) = isoperator(x) && x.kind == Tokens.PAIR_ARROW && x.dot == false
is_in(x) = isoperator(x) && x.kind == Tokens.IN && x.dot == false
is_elof(x) = isoperator(x) && x.kind == Tokens.ELEMENT_OF && x.dot == false
is_colon(x) = isoperator(x) && x.kind == Tokens.COLON
is_prime(x) = isoperator(x) && x.kind == Tokens.PRIME
is_cond(x) = isoperator(x) && x.kind == Tokens.CONDITIONAL
is_where(x) = isoperator(x) && x.kind == Tokens.WHERE
is_anon_func(x) = isoperator(x) && x.kind == Tokens.ANON_FUNC

# PUNCTUATION
is_punc(x) = x.typ === PUNCTUATION && 
    x.kind == Tokens.COMMA && 
    x.kind == Tokens.LPAREN &&
    x.kind == Tokens.RPAREN &&
    x.kind == Tokens.LBRACE &&
    x.kind == Tokens.RBRACE &&
    x.kind == Tokens.LSQUARE &&
    x.kind == Tokens.RSQUARE
is_comma(x) = ispunctuation(x) && x.kind == Tokens.COMMA
is_lparen(x) = ispunctuation(x) && x.kind == Tokens.LPAREN
is_rparen(x) = ispunctuation(x) && x.kind == Tokens.RPAREN
is_lbrace(x) = ispunctuation(x) && x.kind == Tokens.LBRACE
is_rbrace(x) = ispunctuation(x) && x.kind == Tokens.RBRACE
is_lsquare(x) = ispunctuation(x) && x.kind == Tokens.LSQUARE
is_rsquare(x) = ispunctuation(x) && x.kind == Tokens.RSQUARE

# KEYWORD
is_if(x) = iskw(x) && x.kind == Tokens.IF
is_module(x) = iskw(x) && x.kind == Tokens.MODULE
is_import(x) = iskw(x) && x.kind == Tokens.IMPORT
is_importall(x) = iskw(x) && x.kind == Tokens.IMPORTALL


# Literals
is_lit_string(x) = isliteral(x) && (x.kind == Tokens.STRING || x.kind == Tokens.TRIPLE_STRING)


function _arg_id(x)
    if x.typ === IDENTIFIER
        return x
    elseif x.typ === Quotenode
        return x.args[1]
    elseif x.typ === Curly || 
           x.typ === Kw || 
           x.typ === WhereOpCall ||
           (x.typ === UnaryOpCall && is_dddot(x.args[2])) ||
           (x.typ === BinaryOpCall && is_decl(x.args[2])) ||
        return _arg_id(x.args[1])
    else 
        return x
    end
end


function get_where_params(x, params = [])
    if x.typ === WhereOpCall
        for i = 3:length(x.args)
            a = x.args[i]
            if !ispunctuation(a)
                param = rem_subtype(a)
                param = rem_curly(param)
                push!(params, str_value(param))
            end
        end
    end
    return params
end

function get_curly_params(x, params = [])
    if x.typ == Curly
        for i = 2:length(x.args)
            a = x.args[i]
            if !ispunctuation(a)
                param = rem_subtype(a)
                push!(params, str_value(param))
            end
        end
    end
    return params
end




function get_sig_params(x, params = [])
    get_where_params(x, params)
    if x.typ === WhereOpCall && x.args[1].typ === WhereOpCall
        get_where_params(x.args[1], params)
    end
    x = rem_where(x)
    x = rem_call(x)
    get_curly_params(x, params)
    return params
end


function rem_subtype(x)
    if x.typ === BinaryOpCall && isoperator(x.args[2]) && x.args[2].kind == Tokens.ISSUBTYPE
        return x.args[1]
    else
        return x
    end
end

function rem_decl(x)
    if x.typ === BinaryOpCall && is_decl(x.args[2])
        return x.args[1]
    else
        return x
    end
end

function rem_curly(x)
    if x.typ === Curly
        return x.args[1]
    else
        return x
    end
end

function rem_call(x)
    if x.typ === Call
        return x.args[1]
    else
        return x
    end
end

function rem_where(x)
    if x.typ === WhereOpCall
        return rem_where(x.args[1])
    else
        return x
    end
end

function rem_where_subtype(x)
    if x.typ === WhereOpCall || x.typ === BinaryOpCall && x.args[2].kind === Tokens.ISSUBTYPE
        return rem_where_subtype(x.args[1])
    else
        return x
    end
end

function rem_where_decl(x)
    if x.typ === WhereOpCall || x.typ === BinaryOpCall && x.args[2].kind === Tokens.DECLARATION
        return rem_where_decl(x.args[1])
    else
        return x
    end
end

function rem_invis(x)
    if x.typ === InvisBrackets
        return x.args[2]
    else
        return x
    end
end

function rem_dddot(x)
    if x.typ === UnaryOpCall && is_dddot(x.args[2])
        return x.args[1]
    else
        return x
    end
end

function rem_kw(x)
    if x.typ === Kw
        return x.args[1]
    else
        return x
    end
end

# Definitions
function defines_function(x)
    if x.typ === FunctionDef
        return true
    elseif x.typ === BinaryOpCall
        if is_eq(x.args[2])
            sig = x.args[1]
            while true
                if sig.typ === Call || sig.typ === UnaryOpCall || (sig.typ === BinaryOpCall && (sig.args[2].kind == Tokens.DOT || !issyntaxcall(sig.args[2])))
                    return true
                elseif sig.typ === BinaryOpCall && is_decl(sig.args[2]) || sig.typ === WhereOpCall
                    sig = sig.args[1]
                else
                    return false
                end
            end
        end
        return false
    else
        return false
    end
end


defines_macro(x) = x.typ == Macro
defines_datatype(x) = defines_struct(x) || defines_abstract(x) || defines_primitive(x)
defines_struct(x) = x.typ === Struct || defines_mutable(x)
defines_mutable(x) = x.typ === Mutable
defines_abstract(x) = x.typ === Abstract
defines_primitive(x) = x.typ === Primitive
defines_module(x) = x.typ === ModuleH || x.typ === BareModule
defines_anon_function(x) = x.typ === BinaryOpCall && is_anon_func(x.args[2])

function has_sig(x)
    defines_datatype(x) || defines_function(x) || defines_macro(x) || defines_anon_function(x)
end


"""
    get_sig(x)

Returns the full signature of function, macro and datatype definitions. 
Should only be called when has_sig(x) == true.
"""
function get_sig(x)
    if x.typ === BinaryOpCall
        return x.args[1]
    elseif x.typ === Struct ||
        x.typ === FunctionDef ||
        x.typ === Macro
        return x.args[2]
    elseif x.typ === Mutable ||
           x.typ === Abstract ||
           x.typ === Primitive
        return x.args[3]
    end
end

function get_name(x)
    if x.typ === Struct || x.typ === Mutable || x.typ === Abstract || x.typ === Primitive
        sig = get_sig(x)
        sig = rem_subtype(sig)
        sig = rem_where(sig)
        sig = rem_subtype(sig)
        sig = rem_curly(sig)
    elseif x.typ === ModuleH || x.typ === BareModule
        sig = x.args[2] 
    elseif x.typ === FunctionDef || x.typ === Macro
        sig = get_sig(x)
        sig = rem_where(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        if sig.typ === BinaryOpCall && sig.args[2].kind == Tokens.DOT
            if length(sig.args) > 2 && sig.args[3].args isa Vector{EXPR} && length(sig.args[3].args) > 0
                sig = sig.args[3].args[1]
            end
        end
        return sig
        # return get_name(sig)
    elseif x.typ === BinaryOpCall
        if x.args[2].kind == Tokens.DOT
            if length(x.args) > 2 && x.args[3].typ === Quotenode && x.args[3].args isa Vector{EXPR} && length(x.args[3].args) > 0
                return get_name(x.args[3].args[1])
            else
                return x
            end
        end
        sig = x.args[1]
        if sig.typ === UnaryOpCall 
            return get_name(sig.args[1])
        end
        sig = rem_where(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        return get_name(sig)
    else
        sig = x
        if sig.typ === UnaryOpCall 
            sig = sig.args[1]
        end
        sig = rem_where(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
    end
end

function get_args(x)
    if x.typ === IDENTIFIER
        return []
    elseif defines_anon_function(x) && !(x.args[1].typ === TupleH)
        arg = x.args[1]
        arg = rem_invis(arg)
        arg = get_arg_name(arg)
        return [arg]
    elseif x.typ === TupleH
        args = []
        for i = 2:length(x.args)
            arg = x.args[i]
            ispunctuation(arg) && continue
            arg.typ === Parameters && continue
            arg_name = get_arg_name(arg)
            push!(args, arg_name)
        end
        return args
    elseif x.typ === Do
        args = []
        for i = 1:length(x.args[3].args)
            arg = x.args[3].args[i]
            ispunctuation(arg) && continue
            arg.typ === Parameters && continue
            arg_name = get_arg_name(arg)
            push!(args, arg_name)
        end
        return args
    elseif x.typ === Call
        args = []
        sig = rem_where(x)
        sig = rem_decl(sig)
        if sig.typ === Call
            for i = 2:length(sig.args)
                arg = sig.args[i]
                ispunctuation(arg) && continue
                if arg.typ === Parameters
                    for j = 1:length(arg.args)
                        parg = arg.args[j]
                        ispunctuation(parg) && continue
                        parg_name = get_arg_name(parg)
                        push!(args, parg_name)
                    end
                else
                    arg_name = get_arg_name(arg)
                    push!(args, arg_name)
                end
            end
        else
            error("not sig: $sig")
        end
        return args
    elseif x.typ === Struct
        args = []
        for arg in x.args[3]
            if !defines_function(arg)
                arg = rem_decl(arg)
                push!(args, arg)
            end
        end
        return args
    elseif x.typ === Mutable
        args = []
        for arg in x.args[4]
            if !defines_function(arg)
                arg = rem_decl(arg)
                push!(args, arg)
            end
        end
        return args
    elseif x.typ === Flatten
        return get_args(x.args[1])
    elseif x.typ === Generator || x.typ === Flatten
        args = []
        if x.args[1].typ === Flatten || x.args[1].typ === Generator
            append!(args, get_args(x.args[1]))
        end

        if x.args[3].typ === Filter
            return get_args(x.args[3])
        else
            for i = 3:length(x.args)
                arg = x.args[i]
                if is_range(arg)
                    arg = rem_decl(arg.args[1])
                    arg = flatten_tuple(arg)
                    arg = rem_decl.(arg)
                    append!(args, arg)
                end
            end
            return args
        end
    else
        sig = get_sig(x)
        sig = rem_where(sig)
        sig = rem_decl(sig)
        return get_args(sig)
    end
end


function get_arg_name(arg)
    arg = rem_kw(arg)
    arg = rem_dddot(arg)
    arg = rem_where(arg)
    arg = rem_decl(arg)
    arg = rem_subtype(arg)
    arg = rem_curly(arg)
    arg = rem_invis(arg)
end



function get_arg_type(arg)
    if arg.typ === BinaryOpCall && is_decl(arg.args[2])
        return Expr(arg.args[3])
    else
        return :Any
    end
end

get_body(x) = x.typ === Mutable ? x.args[4] : x.args[3]

function flatten_tuple(x, out = [])
    if x.typ === TupleH
        for arg in x
            ispunctuation(arg) && continue    
            flatten_tuple(arg, out)
        end
    elseif x.typ === InvisBrackets
        return flatten_tuple(x.args[2], out)
    else
        push!(out, x)
    end
    return out
end

"""
    get_id(x)

Get the IDENTIFIER name of a variable, possibly in the presence of 
type declaration operators.
"""
function get_id(x)
    if x.typ === BinaryOpCall && (is_issubt(x.args[2]) || is_decl(x.args[2])) ||
        (x.type === UnaryOpCall && is_dddot(x.args[2])) ||
        x.typ === WhereOpCall ||
        x.typ === Curly
        return get_id(x.args[1])
    elseif x.typ === InvisBrackets
        return get_id(x.args[2])
    else
        return x
    end
end


# """
#     get_t(x)

# Basic inference in the presence of type declarations.
# """
# get_t(x) = :Any
# function get_t(x::BinaryOpCall) 
#     if is_decl(x.args[2])
#         return Expr(x.args[3])
#     else
#         return :Any
#     end
# end


# infer_t(x) = :Any
# function infer_t(x::LITERAL)
#     if x.kind == Tokens.INTEGER
#         return :Int
#     elseif x.kind == Tokens.FLOAT
#         return :Float64
#     elseif x.kind == Tokens.STRING
#         return :String
#     elseif x.kind == Tokens.TRIPLE_STRING
#         return :String
#     elseif x.kind == Tokens.CHAR
#         return :Char
#     elseif x.kind == Tokens.TRUE || x.kind == Tokens.FALSE
#         return :Bool
#     elseif x.kind == Tokens.CMD
#         return :Cmd
#     end
# end

# infer_t(x::EXPR{Vect}) = :(Array{Any,1})
# infer_t(x::EXPR{Vcat}) = :(Array{Any,N})
# infer_t(x::EXPR{TypedVcat}) = :(Array{$(Expr(x.args[1])),N})
# infer_t(x::EXPR{Hcat}) = :(Array{Any,2})
# infer_t(x::EXPR{TypedHcat}) = :(Array{$(Expr(x.args[1])),2})
# infer_t(x::EXPR{Quote}) = :Expr
# infer_t(x::EXPR{StringH}) = :String
# infer_t(x::EXPR{Quotenode}) = :QuoteNode


"""
    contributes_scope(x)
Checks whether the body of `x` is included in the toplevel namespace.
"""
contributes_scope(x) = x.typ in (FileH, Begin, Block, Const, Global, Local, If, MacroCall, TopLevel)

