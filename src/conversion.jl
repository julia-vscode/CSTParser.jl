import Base: Expr

# Terminals
function julia_normalization_map(c::Int32, x::Ptr{Nothing})::Int32
    return c == 0x00B5 ? 0x03BC : # micro sign -> greek small letter mu
           c == 0x025B ? 0x03B5 : # latin small letter open e -> greek small letter
           c
end

# Note: This code should be in julia base
function utf8proc_map_custom(str::String, options, func)
    norm_func = @cfunction $func Int32 (Int32, Ptr{Nothing})
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Nothing}, Ptr{Nothing}),
                   str, sizeof(str), C_NULL, 0, options, norm_func, C_NULL)
    nwords < 0 && Base.Unicode.utf8proc_error(nwords)
    buffer = Base.StringVector(nwords * 4)
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Nothing}, Ptr{Nothing}),
                   str, sizeof(str), buffer, nwords, options, norm_func, C_NULL)
    nwords < 0 && Base.Unicode.utf8proc_error(nwords)
    nbytes = ccall(:utf8proc_reencode, Int, (Ptr{UInt8}, Int, Cint), buffer, nwords, options)
    nbytes < 0 && Base.Unicode.utf8proc_error(nbytes)
    return String(resize!(buffer, nbytes))
end

function normalize_julia_identifier(str::AbstractString)
    options = Base.Unicode.UTF8PROC_STABLE | Base.Unicode.UTF8PROC_COMPOSE
    utf8proc_map_custom(String(str), options, julia_normalization_map)
end


function sized_uint_literal(s::AbstractString, b::Integer)
    # We know integers are all ASCII, so we can use sizeof to compute
    # the length of ths string more quickly
    l = (sizeof(s) - 2) * b
    l <= 8   && return Base.parse(UInt8,   s)
    l <= 16  && return Base.parse(UInt16,  s)
    l <= 32  && return Base.parse(UInt32,  s)
    l <= 64  && return Base.parse(UInt64,  s)
    # l <= 128 && return Base.parse(UInt128, s)
    l <= 128 && return Expr(:macrocall, GlobalRef(Core, Symbol("@uint128_str")), nothing, s)
    return Base.parse(BigInt, s)
end

function sized_uint_oct_literal(s::AbstractString)
    s[3] == 0 && return sized_uint_literal(s, 3)
    len = sizeof(s)
    (len < 5  || (len == 5  && s <= "0o377")) && return Base.parse(UInt8, s)
    (len < 8  || (len == 8  && s <= "0o177777")) && return Base.parse(UInt16, s)
    (len < 13 || (len == 13 && s <= "0o37777777777")) && return Base.parse(UInt32, s)
    (len < 24 || (len == 24 && s <= "0o1777777777777777777777")) && return Base.parse(UInt64, s)
    (len < 45 || (len == 45 && s <= "0o3777777777777777777777777777777777777777777")) && return Base.parse(UInt128, s)
    return Base.parse(BigInt, s)
end

function _literal_expr(x)
    if x.kind == Tokens.TRUE
        return true
    elseif x.kind == Tokens.FALSE
        return false
    elseif is_nothing(x)
        return nothing
    elseif x.kind == Tokens.INTEGER || x.kind == Tokens.BIN_INT || x.kind == Tokens.HEX_INT || x.kind == Tokens.OCT_INT
        return Expr_int(x)
    elseif x.kind == Tokens.FLOAT
        return Expr_float(x)
    elseif x.kind == Tokens.CHAR
        return Expr_char(x)
    elseif x.kind == Tokens.MACRO
        return Symbol(x.val)
    elseif x.kind == Tokens.STRING
        return x.val
    elseif x.kind == Tokens.TRIPLE_STRING
        return x.val
    elseif x.kind == Tokens.CMD
        return Expr_cmd(x)
    elseif x.kind == Tokens.TRIPLE_CMD
        return Expr_tcmd(x)
    end
end

const TYPEMAX_INT64_STR = string(typemax(Int))
const TYPEMAX_INT128_STR = string(typemax(Int128))
function Expr_int(x)
    is_hex = is_oct = is_bin = false
    val = replace(x.val, "_" => "")
    if sizeof(val) > 2 && val[1] == '0'
        c = val[2]
        c == 'x' && (is_hex = true)
        c == 'o' && (is_oct = true)
        c == 'b' && (is_bin = true)
    end
    is_hex && return sized_uint_literal(val, 4)
    is_oct && return sized_uint_oct_literal(val)
    is_bin && return sized_uint_literal(val, 1)
    # sizeof(val) <= sizeof(TYPEMAX_INT64_STR) && return Base.parse(Int64, val)
    return Meta.parse(val)
    # # val < TYPEMAX_INT64_STR && return Base.parse(Int64, val)
    # sizeof(val) <= sizeof(TYPEMAX_INTval < TYPEMAX_INT128_STR128_STR) && return Base.parse(Int128, val)
    # # val < TYPEMAX_INT128_STR && return Base.parse(Int128, val)
    # Base.parse(BigInt, val)
end

function Expr_float(x)
    if 'f' in x.val
        return Base.parse(Float32, replace(x.val, 'f' => 'e'))
    end
    Base.parse(Float64, replace(x.val, "_" => ""))
end
function Expr_char(x)
    val = _unescape_string(x.val[2:prevind(x.val, sizeof(x.val))])
    # one byte e.g. '\xff' maybe not valid UTF-8
    # but we want to use the raw value as a codepoint in this case
    sizeof(val) == 1 && return Char(codeunit(val, 1))
    length(val) == 1 || error("Invalid character literal: $(Vector{UInt8}(x.val))")
    val[1]
end


# Expressions

# Fallback
function Expr(x::EXPR)
    if isidentifier(x)
        return Symbol(normalize_julia_identifier(x.val))
    elseif iskw(x)
        if x.kind == Tokens.BREAK
            return Expr(:break)
        elseif x.kind == Tokens.CONTINUE
            return Expr(:continue)
        else
            return Symbol(lowercase(string(x.kind)))
        end
    elseif isoperator(x)
        return x.dot ? Symbol(:., UNICODE_OPS_REVERSE[x.kind]) : UNICODE_OPS_REVERSE[x.kind]
    elseif ispunctuation(x)
        return string(x.kind)
    elseif isliteral(x)
        return _literal_expr(x)
    elseif x.typ === UnaryOpCall
        return _unary_expr(x)
    elseif x.typ === BinaryOpCall
        return _binary_expr(x)
    elseif x.typ === WhereOpCall
        return _where_expr(x)
    elseif x.typ === ConditionalOpCall
        return Expr(:if, Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))
    elseif x.typ === ErrorToken
        ret = Expr(:error)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === ChainOpCall
        ret = Expr(:call, Expr(x.args[2]))
        for i = 1:length(x.args)
            if isodd(i)
                push!(ret.args, Expr(x.args[i]))
            end
        end
        return ret
    elseif x.typ === Comparison
        ret = Expr(:comparison)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === ColonOpCall
        return Expr(:call, :(:), Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))
    elseif x.typ === TopLevel
        ret = Expr(:toplevel)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === MacroName
        if isidentifier(x.args[2])
            if x.args[2].val == "."
                return Symbol("@", "__dot__")
            else
                return Symbol("@", x.args[2].val)
            end
        else
            return Symbol("@")
        end
    elseif x.typ === MacroCall
        ret = Expr(:macrocall)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        insert!(ret.args, 2, nothing)
        if ret.args[1] isa Expr && ret.args[1].head == :. && string(ret.args[1].args[2].value)[1] != '@'
            clear_at!(ret.args[1])
            ret.args[1].args[2] = QuoteNode(Symbol(string('@', ret.args[1].args[2].value)))
        end
        ret
    elseif x.typ === x_Str
        if x.args[1].typ === BinaryOpCall && issyntaxcall(x.args[1].args[2])
            mname = Expr(x.args[1])
            mname.args[2] = QuoteNode(Symbol("@", mname.args[2].value, "_str"))
            ret = Expr(:macrocall, mname, nothing)
        else
            ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_str"), nothing)
        end
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    elseif x.typ === x_Cmd
        ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"), nothing)
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    elseif x.typ === Quotenode
        return QuoteNode(Expr(x.args[end]))
    elseif x.typ === Call
        if x.args[1].kind === Tokens.ISSUBTYPE || x.args[1].kind === Tokens.ISSUPERTYPE
            ret = Expr(Expr(x.args[1]))
            for i in 2:length(x.args)
                a = x.args[i]
                if a.typ === Parameters
                    insert!(ret.args, 2, Expr(a))
                elseif !(ispunctuation(a))
                    push!(ret.args, Expr(a))
                end
            end
            return ret
        end
        ret = Expr(:call)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 2, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret    
    elseif x.typ === Braces
        ret = Expr(:braces)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 1, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Struct
        return Expr(:struct, false, Expr(x.args[2]), Expr(x.args[3]))
    elseif x.typ === Mutable
        return length(x.args) == 4 ? Expr(:struct, true, Expr(x.args[2]), Expr(x.args[3])) : Expr(:struct, true, Expr(x.args[3]), Expr(x.args[4]))
    elseif x.typ === Abstract
        return length(x.args) == 2 ? Expr(:abstract, Expr(x.args[2])) : Expr(:abstract, Expr(x.args[3]))
    elseif x.typ === Primitive
        return Expr(:primitive, Expr(x.args[3]), Expr(x.args[4]))
    elseif x.typ === FunctionDef
        ret = Expr(:function)
        for a in x.args
            if !(ispunctuation(a) || iskw(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Macro
        if length(x.args) == 3
            Expr(:macro, Expr(x.args[2]))
        else
            Expr(:macro, Expr(x.args[2]), Expr(x.args[3]))
        end
    elseif x.typ === ModuleH
        return Expr(:module, true, Expr(x.args[2]), Expr(x.args[3]))
    elseif x.typ === BareModule
        return Expr(:module, false, Expr(x.args[2]), Expr(x.args[3]))
    elseif x.typ === If
        return _if_expr(x)
    elseif x.typ === Try
        ret = Expr(:try)
        for a in x.args
            if !(ispunctuation(a) || iskw(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Let
        return _let_expr(x)
    elseif x.typ === Do
        return Expr(:do, Expr(x.args[1]), Expr(:->, Expr(x.args[3]), Expr(x.args[4])))
    elseif x.typ === Outer
        return Expr(:outer, Expr(x.args[2]))
    elseif x.typ === For
        ret = Expr(:for)
        if x.args[2].typ === Block
            arg = Expr(:block)
            for a in x.args[2].args
                if !(ispunctuation(a))
                    push!(arg.args, fix_range(a))
                end
            end
            push!(ret.args, arg)
        else
            push!(ret.args, fix_range(x.args[2]))
        end
        push!(ret.args, Expr(x.args[3]))
        return ret
    elseif x.typ === While
        ret = Expr(:while)
        for a in x.args
            if !(ispunctuation(a) || iskw(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === TupleH
        ret = Expr(:tuple)
        for a in x.args
            if a.typ == Parameters
                insert!(ret.args, 1, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Curly
        ret = Expr(:curly)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 2, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Vect
        ret = Expr(:vect)
        for a in x.args
            if a.typ === Parameters
                pushfirst!(ret.args, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Row
        ret = Expr(:row)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Hcat
        ret = Expr(:hcat)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Vcat
        ret = Expr(:vcat)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Block
        ret = Expr(:block)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Kw
        return Expr(:kw, Expr(x.args[1]), Expr(x.args[3]))
    elseif x.typ === Parameters
        ret = Expr(:parameters)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 2, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Return
        ret = Expr(:return)
        for i = 2:length(x.args)
            a = x.args[i]
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.typ === InvisBrackets
        return Expr(x.args[2])
    elseif x.typ === Begin
        return Expr(x.args[2])
    elseif x.typ === Quote
        if x.args[2].typ === InvisBrackets && (isoperator(x.args[2].args[2]) || isliteral(x.args[2].args[2]) || isidentifier(x.args[2].args[2]))
            return QuoteNode(Expr(x.args[2]))
        else
            return Expr(:quote, Expr(x.args[2]))
        end
    elseif x.typ === Global
        ret = Expr(:global)
        if x.args[2].typ === Const
            ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
        elseif length(x.args) == 2 && x.args[2].typ === TupleH
            for a in x.args[2].args
                if !(ispunctuation(a))
                    push!(ret.args, Expr(a))
                end
            end
        else
            for i = 2:length(x.args)
                a = x.args[i]
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Local
        ret = Expr(:local)
        if x.args[2].typ === Const
            ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
        elseif length(x.args) == 2 && x.args[2].typ === TupleH
            for a in x.args[2].args
                if !(ispunctuation(a))
                    push!(ret.args, Expr(a))
                end
            end
        else
            for i = 2:length(x.args)
                a = x.args[i]
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Const
        ret = Expr(:const)
        for i = 2:length(x.args)
            a = x.args[i]
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.typ === GlobalRefDoc
        return GlobalRef(Core, Symbol("@doc"))
    elseif x.typ === Ref
        ret = Expr(:ref)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 2, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === TypedHcat
        ret = Expr(:typed_hcat)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === TypedVcat
        ret = Expr(:typed_vcat)
        for a in x.args
            if a.typ === Parameters
                insert!(ret.args, 2, Expr(a))
            elseif !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Comprehension || x.typ === DictComprehension
        ret = Expr(:comprehension)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Flatten
        iters, args = get_inner_gen(x)
        i = popfirst!(iters)
        ex = Expr(:generator, Expr(args[1]), convert_iter_assign(i[1]))
        for i in iters
            if length(i) == 1
                ex = Expr(:generator, ex, convert_iter_assign(i[1]))
                ex = Expr(:flatten, ex)
            else
                ex = Expr(:generator, ex)
                for j in i
                    push!(ex.args, convert_iter_assign(j))
                end
                ex = Expr(:flatten, ex)
            end
        end
        return ex
    elseif x.typ === Generator
        ret = Expr(:generator, Expr(x.args[1]))
        for i = 3:length(x.args)
            a = x.args[i]
            if !(ispunctuation(a))
                push!(ret.args, convert_iter_assign(a))
            end
        end
        return ret
    elseif x.typ === Filter
        ret = Expr(:filter)
        push!(ret.args, convert_iter_assign(last(x.args)))
        for i in 1:length(x.args) - 1
            a = x.args[i]
            if !(is_if(a) || ispunctuation(a))
                push!(ret.args, convert_iter_assign(a))
            end
        end
        return ret
    elseif x.typ === TypedComprehension
        ret = Expr(:typed_comprehension)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === Import
        return expr_import(x, :import)
    elseif x.typ === ImportAll
        return expr_import(x, :importall)
    elseif x.typ === Using
        return expr_import(x, :using)
    elseif x.typ === Export
        ret = Expr(:export)
        for i = 2:length(x.args)
            a = x.args[i]
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    elseif x.typ === FileH
        ret = Expr(:file)
        for a in x.args
            push!(ret.args, Expr(a))
        end
        return ret
    elseif x.typ === StringH
        ret = Expr(:string)
        for (i, a) in enumerate(x.args)
            if a.typ === UnaryOpCall
                a = a.args[2]
            elseif isliteral(a) && a.kind == Tokens.STRING && span(a) == 0 || ((i == 1 || i == length(x.args)) && span(a) == 1) || isempty(a.val)
                continue
            else isliteral(a) && a.kind == Tokens.TRIPLE_STRING && span(a) == 0 || ((i == 1 || i == length(x.args)) && span(a) == 3) || isempty(a.val)
            end
            push!(ret.args, Expr(a))
        end
        return ret
    else
        ret = Expr(:call)
        for a in x.args
            if !(ispunctuation(a))
                push!(ret.args, Expr(a))
            end
        end
        return ret
    end
end

# Op. expressions

function _unary_expr(x)
    if isoperator(x.args[1]) && issyntaxunarycall(x.args[1])
        Expr(Expr(x.args[1]), Expr(x.args[2]))
    elseif isoperator(x.args[2]) && issyntaxunarycall(x.args[2])
        Expr(Expr(x.args[2]), Expr(x.args[1]))
    else
        Expr(:call, Expr(x.args[1]), Expr(x.args[2]))
    end
end
function _binary_expr(x)
    if issyntaxcall(x.args[2]) && !(x.args[2].kind in (Tokens.COLON,))
        Expr(Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
    else
        Expr(:call, Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
    end
end

function _where_expr(x)
    ret = Expr(:where, Expr(x.args[1]))
    for i = 3:length(x.args)
        a = x.args[i]
        if a.typ === Parameters
            insert!(ret.args, 2, Expr(a))
        elseif !(ispunctuation(a) || iskw(a))
            push!(ret.args, Expr(a))
        end
    end
    return ret
end


# cross compatability for line number insertion in macrocalls
if VERSION > v"1.1-"
    Expr_cmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, x.val)
    Expr_tcmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, x.val)
else
    Expr_cmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
    Expr_tcmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
end


function clear_at!(x)
    if x isa Expr && x.head == :.
        if x.args[2] isa QuoteNode && string(x.args[2].value)[1] == '@'
            x.args[2].value = Symbol(string(x.args[2].value)[2:end])
        end
        if x.args[1] isa Symbol && string(x.args[1])[1] == '@'
            x.args[1] = Symbol(string(x.args[1])[2:end])
        else
            clear_at!(x.args[1])
        end
    end
end


"""
    remlineinfo!(x)
Removes line info expressions. (i.e. Expr(:line, 1))
"""
function remlineinfo!(x)
    if isa(x, Expr)
        if x.head == :macrocall && x.args[2] != nothing
            id = findall(map(x->(isa(x, Expr) && x.head == :line) || (@isdefined(LineNumberNode) && x isa LineNumberNode), x.args))
            deleteat!(x.args, id)
            for j in x.args
                remlineinfo!(j)
            end
            insert!(x.args, 2, nothing)
        else
            id = findall(map(x->(isa(x, Expr) && x.head == :line) || (@isdefined(LineNumberNode) && x isa LineNumberNode), x.args))
            deleteat!(x.args, id)
            for j in x.args
                remlineinfo!(j)
            end
        end
        if x.head == :elseif && x.args[1] isa Expr && x.args[1].head == :block && length(x.args[1].args) == 1
            x.args[1] = x.args[1].args[1]
        end
    end
    x
end

function _if_expr(x)
    ret = Expr(:if)
    iselseif = false
    n = length(x.args)
    i = 0
    while i < n
        i += 1
        a = x.args[i]
        if iskw(a) && a.kind == Tokens.ELSEIF
            i += 1
            r1 = Expr(x.args[i].args[1])
            push!(ret.args, Expr(:elseif, r1.args...))
        elseif !(ispunctuation(a) || iskw(a))
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function _let_expr(x)
    ret = Expr(:let)
    if length(x.args) == 3
        push!(ret.args, Expr(:block))
        push!(ret.args, Expr(x.args[2]))
        return ret
    elseif x.args[2].typ === Block
        arg = Expr(:block)
        for a in x.args[2].args
            if !(ispunctuation(a))
                push!(arg.args, fix_range(a))
            end
        end
        push!(ret.args, arg)
    else
        push!(ret.args, fix_range(x.args[2]))
    end
    push!(ret.args, Expr(x.args[3]))
    ret
end

function fix_range(a)
    if a.typ === BinaryOpCall && (is_in(a.args[2]) || is_elof(a.args[2]))
        Expr(:(=), Expr(a.args[1]), Expr(a.args[3]))
    else
        Expr(a)
    end
end

function get_inner_gen(x, iters = [], arg = []) 
    if x.typ == Flatten
        get_inner_gen(x.args[1], iters, arg)
    elseif x.typ === Generator
        # push!(iters, get_iter(x))
        get_iters(x, iters)
        if x.args[1].typ === Generator || x.args[1].typ === Flatten
            get_inner_gen(x.args[1], iters, arg)
        else
            push!(arg, x.args[1])
        end
    end
    return iters, arg 
end

function get_iter(x) 
    if x.typ === Generator
        return x.args[3]
    end
end

function get_iters(x, iters)
    iters1 = []
    if x.typ === Generator
        # return x.args[3]
        for i = 3:length(x.args)
            if x.args[i].typ !== PUNCTUATION
                push!(iters1, x.args[i])
            end
        end
    end
    push!(iters, iters1)
end

function convert_iter_assign(a)
    if a.typ === BinaryOpCall && (is_in(a.args[2]) || is_elof(a.args[2]))
        return Expr(:(=), Expr(a.args[1]), Expr(a.args[3]))
    else
        return Expr(a)
    end
end

function _get_import_block(x, i, ret)
    while is_dot(x.args[i + 1])
        i += 1
        push!(ret.args, :.)
    end
    while i < length(x.args) && !(is_comma(x.args[i + 1]))
        i += 1
        a = x.args[i]
        if !(ispunctuation(a)) && !(is_dot(a) || is_colon(a))
            push!(ret.args, Expr(a))
        end
    end

    return i
end

function expr_import(x, kw)
    col = findall(a->isoperator(a) && precedence(a) == ColonOp, x.args)
    comma = findall(is_comma, x.args)
    
    header = []
    args = [Expr(:.)]
    i = 1 #skip keyword
    while i < length(x.args)
        i += 1
        a = x.args[i]
        if is_colon(a)
            push!(header, popfirst!(args))
            push!(args, Expr(:.))
        elseif is_comma(a)
            push!(args, Expr(:.))
        elseif !(ispunctuation(a))
            push!(last(args).args, Expr(a))
        end
    end
    if isempty(header)
        return Expr(kw, args...)
    else
        return Expr(kw, Expr(:(:), header..., args...))
    end
end



const UNICODE_OPS_REVERSE = Dict{Tokenize.Tokens.Kind,Symbol}()
for (k, v) in Tokenize.Tokens.UNICODE_OPS
    UNICODE_OPS_REVERSE[v] = Symbol(k)
end

UNICODE_OPS_REVERSE[Tokens.EQ] = :(=)
UNICODE_OPS_REVERSE[Tokens.PLUS_EQ] = :(+=)
UNICODE_OPS_REVERSE[Tokens.MINUS_EQ] = :(-=)
UNICODE_OPS_REVERSE[Tokens.STAR_EQ] = :(*=)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH_EQ] = :(/=)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH_EQ] = :(//=)
UNICODE_OPS_REVERSE[Tokens.OR_EQ] = :(|=)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_EQ] = :(^=)
UNICODE_OPS_REVERSE[Tokens.DIVISION_EQ] = :(÷=)
UNICODE_OPS_REVERSE[Tokens.REM_EQ] = :(%=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT_EQ] = :(<<=)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT_EQ] = :(>>=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT] = :(<<)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT] = :(>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT] = :(>>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT_EQ] = :(>>>=)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH_EQ] = :(\=)
UNICODE_OPS_REVERSE[Tokens.AND_EQ] = :(&=)
UNICODE_OPS_REVERSE[Tokens.COLON_EQ] = :(:=)
UNICODE_OPS_REVERSE[Tokens.PAIR_ARROW] = :(=>)
UNICODE_OPS_REVERSE[Tokens.APPROX] = :(~)
UNICODE_OPS_REVERSE[Tokens.EX_OR_EQ] = :($=)
UNICODE_OPS_REVERSE[Tokens.XOR_EQ] = :(⊻=)
UNICODE_OPS_REVERSE[Tokens.RIGHT_ARROW] = :(-->)
UNICODE_OPS_REVERSE[Tokens.LAZY_OR] = :(||)
UNICODE_OPS_REVERSE[Tokens.LAZY_AND] = :(&&)
UNICODE_OPS_REVERSE[Tokens.ISSUBTYPE] = :(<:)
UNICODE_OPS_REVERSE[Tokens.ISSUPERTYPE] = :(>:)
UNICODE_OPS_REVERSE[Tokens.GREATER] = :(>)
UNICODE_OPS_REVERSE[Tokens.LESS] = :(<)
UNICODE_OPS_REVERSE[Tokens.GREATER_EQ] = :(>=)
UNICODE_OPS_REVERSE[Tokens.GREATER_THAN_OR_EQUAL_TO] = :(≥)
UNICODE_OPS_REVERSE[Tokens.LESS_EQ] = :(<=)
UNICODE_OPS_REVERSE[Tokens.LESS_THAN_OR_EQUAL_TO] = :(≤)
UNICODE_OPS_REVERSE[Tokens.EQEQ] = :(==)
UNICODE_OPS_REVERSE[Tokens.EQEQEQ] = :(===)
UNICODE_OPS_REVERSE[Tokens.IDENTICAL_TO] = :(≡)
UNICODE_OPS_REVERSE[Tokens.NOT_EQ] = :(!=)
UNICODE_OPS_REVERSE[Tokens.NOT_EQUAL_TO] = :(≠)
UNICODE_OPS_REVERSE[Tokens.NOT_IS] = :(!==)
UNICODE_OPS_REVERSE[Tokens.NOT_IDENTICAL_TO] = :(≢)
UNICODE_OPS_REVERSE[Tokens.IN] = :(in)
UNICODE_OPS_REVERSE[Tokens.ISA] = :(isa)
UNICODE_OPS_REVERSE[Tokens.LPIPE] = :(<|)
UNICODE_OPS_REVERSE[Tokens.RPIPE] = :(|>)
UNICODE_OPS_REVERSE[Tokens.COLON] = :(:)
UNICODE_OPS_REVERSE[Tokens.DDOT] = :(..)
UNICODE_OPS_REVERSE[Tokens.EX_OR] = :($)
UNICODE_OPS_REVERSE[Tokens.PLUS] = :(+)
UNICODE_OPS_REVERSE[Tokens.MINUS] = :(-)
UNICODE_OPS_REVERSE[Tokens.PLUSPLUS] = :(++)
UNICODE_OPS_REVERSE[Tokens.OR] = :(|)
UNICODE_OPS_REVERSE[Tokens.STAR] = :(*)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH] = :(/)
UNICODE_OPS_REVERSE[Tokens.REM] = :(%)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH] = :(\)
UNICODE_OPS_REVERSE[Tokens.AND] = :(&)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH] = :(//)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_ACCENT] = :(^)
UNICODE_OPS_REVERSE[Tokens.DECLARATION] = :(::)
UNICODE_OPS_REVERSE[Tokens.CONDITIONAL] = :?
UNICODE_OPS_REVERSE[Tokens.DOT] = :(.)
UNICODE_OPS_REVERSE[Tokens.NOT] = :(!)
UNICODE_OPS_REVERSE[Tokens.PRIME] = Symbol(''')
UNICODE_OPS_REVERSE[Tokens.DDDOT] = :(...)
UNICODE_OPS_REVERSE[Tokens.TRANSPOSE] = Symbol(".'")
UNICODE_OPS_REVERSE[Tokens.ANON_FUNC] = :(->)
UNICODE_OPS_REVERSE[Tokens.WHERE] = :where
