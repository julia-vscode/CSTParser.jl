function is_func_call(x)
    if typof(x) === Call
        return true
    elseif typof(x) === WhereOpCall
        return is_func_call(x.args[1])
    elseif typof(x) === InvisBrackets
        return is_func_call(x.args[2])
    elseif typof(x) === UnaryOpCall
        return !(isoperator(x.args[1]) && (kindof(x.args[1]) === Tokens.EX_OR || kindof(x.args[1]) === Tokens.DECLARATION))
    elseif typof(x) === BinaryOpCall
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

is_assignment(x) = typof(x) === BinaryOpCall && kindof(x.args[2]) === Tokens.EQ

# OPERATOR
is_exor(x) = isoperator(x) && kindof(x) == Tokens.EX_OR && x.dot == false
is_decl(x) = isoperator(x) && kindof(x) == Tokens.DECLARATION
is_issubt(x) = isoperator(x) && kindof(x) == Tokens.ISSUBTYPE
is_issupt(x) = isoperator(x) && kindof(x) == Tokens.ISSUPERTYPE
is_and(x) = isoperator(x) && kindof(x) == Tokens.AND && x.dot == false
is_not(x) = isoperator(x) && kindof(x) == Tokens.NOT && x.dot == false
is_plus(x) = isoperator(x) && kindof(x) == Tokens.PLUS && x.dot == false
is_minus(x) = isoperator(x) && kindof(x) == Tokens.MINUS && x.dot == false
is_star(x) = isoperator(x) && kindof(x) == Tokens.STAR && x.dot == false
is_eq(x) = isoperator(x) && kindof(x) == Tokens.EQ && x.dot == false
is_dot(x) = isoperator(x) && kindof(x) == Tokens.DOT
is_ddot(x) = isoperator(x) && kindof(x) == Tokens.DDOT
is_dddot(x) = isoperator(x) && kindof(x) == Tokens.DDDOT
is_pairarrow(x) = isoperator(x) && kindof(x) == Tokens.PAIR_ARROW && x.dot == false
is_in(x) = isoperator(x) && kindof(x) == Tokens.IN && x.dot == false
is_elof(x) = isoperator(x) && kindof(x) == Tokens.ELEMENT_OF && x.dot == false
is_colon(x) = isoperator(x) && kindof(x) == Tokens.COLON
is_prime(x) = isoperator(x) && kindof(x) == Tokens.PRIME
is_cond(x) = isoperator(x) && kindof(x) == Tokens.CONDITIONAL
is_where(x) = isoperator(x) && kindof(x) == Tokens.WHERE
is_anon_func(x) = isoperator(x) && kindof(x) == Tokens.ANON_FUNC

# PUNCTUATION
is_punc(x) = typof(x) === PUNCTUATION && 
    kindof(x) == Tokens.COMMA && 
    kindof(x) == Tokens.LPAREN &&
    kindof(x) == Tokens.RPAREN &&
    kindof(x) == Tokens.LBRACE &&
    kindof(x) == Tokens.RBRACE &&
    kindof(x) == Tokens.LSQUARE &&
    kindof(x) == Tokens.RSQUARE
is_comma(x) = ispunctuation(x) && kindof(x) == Tokens.COMMA
is_lparen(x) = ispunctuation(x) && kindof(x) == Tokens.LPAREN
is_rparen(x) = ispunctuation(x) && kindof(x) == Tokens.RPAREN
is_lbrace(x) = ispunctuation(x) && kindof(x) == Tokens.LBRACE
is_rbrace(x) = ispunctuation(x) && kindof(x) == Tokens.RBRACE
is_lsquare(x) = ispunctuation(x) && kindof(x) == Tokens.LSQUARE
is_rsquare(x) = ispunctuation(x) && kindof(x) == Tokens.RSQUARE

# KEYWORD
is_if(x) = iskw(x) && kindof(x) == Tokens.IF
is_module(x) = iskw(x) && kindof(x) == Tokens.MODULE
is_import(x) = iskw(x) && kindof(x) == Tokens.IMPORT
is_importall(x) = iskw(x) && kindof(x) == Tokens.IMPORTALL


# Literals
is_lit_string(x) = isliteral(x) && (kindof(x) == Tokens.STRING || kindof(x) == Tokens.TRIPLE_STRING)


function _arg_id(x)
    if typof(x) === IDENTIFIER
        return x
    elseif typof(x) === Quotenode
        return x.args[1]
    elseif typof(x) === Curly || 
        typof(x) === Kw || 
        typof(x) === WhereOpCall ||
           (typof(x) === UnaryOpCall && is_dddot(x.args[2])) ||
           (typof(x) === BinaryOpCall && is_decl(x.args[2])) ||
        return _arg_id(x.args[1])
    else 
        return x
    end
end


function get_where_params(x, params = [])
    if typof(x) === WhereOpCall
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
    if typof(x) == Curly
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
    if typof(x) === WhereOpCall && typof(x.args[1]) === WhereOpCall
        get_where_params(x.args[1], params)
    end
    x = rem_where(x)
    x = rem_call(x)
    get_curly_params(x, params)
    return params
end


function rem_subtype(x)
    if typof(x) === BinaryOpCall && isoperator(x.args[2]) && kindof(x.args[2]) == Tokens.ISSUBTYPE
        return x.args[1]
    else
        return x
    end
end

function rem_decl(x)
    if typof(x) === BinaryOpCall && is_decl(x.args[2])
        return x.args[1]
    else
        return x
    end
end

function rem_curly(x)
    if typof(x) === Curly
        return x.args[1]
    else
        return x
    end
end

function rem_call(x)
    if typof(x) === Call
        return x.args[1]
    else
        return x
    end
end

function rem_where(x)
    if typof(x) === WhereOpCall
        return rem_where(x.args[1])
    else
        return x
    end
end

function rem_where_subtype(x)
    if typof(x) === WhereOpCall || typof(x) === BinaryOpCall && kindof(x.args[2]) === Tokens.ISSUBTYPE
        return rem_where_subtype(x.args[1])
    else
        return x
    end
end

function rem_where_decl(x)
    if typof(x) === WhereOpCall || typof(x) === BinaryOpCall && kindof(x.args[2]) === Tokens.DECLARATION
        return rem_where_decl(x.args[1])
    else
        return x
    end
end

function rem_invis(x)
    if typof(x) === InvisBrackets
        return x.args[2]
    else
        return x
    end
end

function rem_dddot(x)
    if typof(x) === UnaryOpCall && is_dddot(x.args[2])
        return x.args[1]
    else
        return x
    end
end

function rem_kw(x)
    if typof(x) === Kw
        return x.args[1]
    else
        return x
    end
end

# Definitions
function defines_function(x)
    if typof(x) === FunctionDef
        return true
    elseif typof(x) === BinaryOpCall
        if is_eq(x.args[2])
            sig = x.args[1]
            while true
                if typof(sig) === Call || typof(sig) === UnaryOpCall || (typof(sig) === BinaryOpCall && (kindof(sig.args[2]) == Tokens.DOT || !issyntaxcall(sig.args[2])))
                    return true
                elseif typof(sig) === BinaryOpCall && is_decl(sig.args[2]) || typof(sig) === WhereOpCall
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


defines_macro(x) = typof(x) == Macro
defines_datatype(x) = defines_struct(x) || defines_abstract(x) || defines_primitive(x)
defines_struct(x) = typof(x) === Struct || defines_mutable(x)
defines_mutable(x) = typof(x) === Mutable
defines_abstract(x) = typof(x) === Abstract
defines_primitive(x) = typof(x) === Primitive
defines_module(x) = typof(x) === ModuleH || typof(x) === BareModule
defines_anon_function(x) = typof(x) === BinaryOpCall && is_anon_func(x.args[2])

function has_sig(x)
    defines_datatype(x) || defines_function(x) || defines_macro(x) || defines_anon_function(x)
end


"""
    get_sig(x)

Returns the full signature of function, macro and datatype definitions. 
Should only be called when has_sig(x) == true.
"""
function get_sig(x)
    if typof(x) === BinaryOpCall
        return x.args[1]
    elseif typof(x) === Struct ||
        typof(x) === FunctionDef ||
        typof(x) === Macro
        return x.args[2]
    elseif typof(x) === Mutable ||
           typof(x) === Abstract ||
           typof(x) === Primitive
        length(x.args) < 3 && error(x)
        return x.args[3]
    end
end

function get_name(x)
    if typof(x) === Struct || typof(x) === Mutable || typof(x) === Abstract || typof(x) === Primitive
        sig = get_sig(x)
        sig = rem_subtype(sig)
        sig = rem_where(sig)
        sig = rem_subtype(sig)
        sig = rem_curly(sig)
    elseif typof(x) === ModuleH || typof(x) === BareModule
        sig = x.args[2] 
    elseif typof(x) === FunctionDef || typof(x) === Macro
        sig = get_sig(x)
        sig = rem_where(sig)
        sig = rem_decl(sig)
        sig = rem_call(sig)
        sig = rem_curly(sig)
        sig = rem_invis(sig)
        if typof(sig) === BinaryOpCall && kindof(sig.args[2]) == Tokens.DOT
            if length(sig.args) > 2 && sig.args[3].args isa Vector{EXPR} && length(sig.args[3].args) > 0
                sig = sig.args[3].args[1]
            end
        end
        return sig
        # return get_name(sig)
    elseif typof(x) === BinaryOpCall
        x.args === nothing && return x
        length(x.args) < 2 && return x
        if kindof(x.args[2]) == Tokens.DOT
            if length(x.args) > 2 && typof(x.args[3]) === Quotenode && x.args[3].args isa Vector{EXPR} && length(x.args[3].args) > 0
                return get_name(x.args[3].args[1])
            else
                return x
            end
        end
        sig = x.args[1]
        if typof(sig) === UnaryOpCall 
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
        if typof(sig) === UnaryOpCall 
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
    if typof(x) === IDENTIFIER
        return []
    elseif defines_anon_function(x) && !(typof(x.args[1]) === TupleH)
        arg = x.args[1]
        arg = rem_invis(arg)
        arg = get_arg_name(arg)
        return [arg]
    elseif typof(x) === TupleH
        args = []
        for i = 2:length(x.args)
            arg = x.args[i]
            ispunctuation(arg) && continue
            typof(arg) === Parameters && continue
            arg_name = get_arg_name(arg)
            push!(args, arg_name)
        end
        return args
    elseif typof(x) === Do
        args = []
        for i = 1:length(x.args[3].args)
            arg = x.args[3].args[i]
            ispunctuation(arg) && continue
            typof(arg) === Parameters && continue
            arg_name = get_arg_name(arg)
            push!(args, arg_name)
        end
        return args
    elseif typof(x) === Call
        args = []
        sig = rem_where(x)
        sig = rem_decl(sig)
        if typof(sig) === Call
            for i = 2:length(sig.args)
                arg = sig.args[i]
                ispunctuation(arg) && continue
                if typof(arg) === Parameters
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
    elseif typof(x) === Struct
        args = []
        for arg in x.args[3]
            if !defines_function(arg)
                arg = rem_decl(arg)
                push!(args, arg)
            end
        end
        return args
    elseif typof(x) === Mutable
        args = []
        for arg in x.args[4]
            if !defines_function(arg)
                arg = rem_decl(arg)
                push!(args, arg)
            end
        end
        return args
    elseif typof(x) === Flatten
        return get_args(x.args[1])
    elseif typof(x) === Generator || typof(x) === Flatten
        args = []
        if typof(x.args[1]) === Flatten || typof(x.args[1]) === Generator
            append!(args, get_args(x.args[1]))
        end

        if typof(x.args[3]) === Filter
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
    if typof(arg) === BinaryOpCall && is_decl(arg.args[2])
        return Expr(arg.args[3])
    else
        return :Any
    end
end

get_body(x) = typof(x) === Mutable ? x.args[4] : x.args[3]

function flatten_tuple(x, out = [])
    if typof(x) === TupleH
        for arg in x
            ispunctuation(arg) && continue    
            flatten_tuple(arg, out)
        end
    elseif typof(x) === InvisBrackets
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
    if typof(x) === BinaryOpCall && (is_issubt(x.args[2]) || is_decl(x.args[2])) ||
        (typof(x) === UnaryOpCall && is_dddot(x.args[2])) ||
        typof(x) === WhereOpCall ||
        typof(x) === Curly
        return get_id(x.args[1])
    elseif typof(x) === InvisBrackets
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
#     if kindof(x) == Tokens.INTEGER
#         return :Int
#     elseif kindof(x) == Tokens.FLOAT
#         return :Float64
#     elseif kindof(x) == Tokens.STRING
#         return :String
#     elseif kindof(x) == Tokens.TRIPLE_STRING
#         return :String
#     elseif kindof(x) == Tokens.CHAR
#         return :Char
#     elseif kindof(x) == Tokens.TRUE || kindof(x) == Tokens.FALSE
#         return :Bool
#     elseif kindof(x) == Tokens.CMD
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
contributes_scope(x) = typof(x) in (FileH, Begin, Block, Const, Global, Local, If, MacroCall, TopLevel)

