import Core: Expr

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
    # (len < 45 || (len == 45 && s <= "0o3777777777777777777777777777777777777777777")) && return Base.parse(UInt128, s)
    # return Base.parse(BigInt, s)
    (len < 45 || (len == 45 && s <= "0o3777777777777777777777777777777777777777777")) && return Expr(:macrocall, GlobalRef(Core, Symbol("@uint128_str")), nothing, s)
    return Meta.parse(s)
end

function _literal_expr(x)
    if headof(x) === :(var"true")
        return true
    elseif headof(x) === :(var"false")
        return false
    elseif is_nothing(x)
        return nothing
    elseif headof(x) === :integer || headof(x) === :bin_int || headof(x) === :hexint || headof(x) === :octint
        return Expr_int(x)
    elseif isfloat(x)
        return Expr_float(x)
    elseif ischar(x)
        return Expr_char(x)
    elseif headof(x) === :macro
        return Symbol(valof(x))
    elseif headof(x) === :string || headof(x) === :triplestring
        return valof(x)
    elseif headof(x) === :cmd
        return Expr_cmd(x)
    elseif headof(x) === :triplecmd
        return Expr_tcmd(x)
    end
end

const TYPEMAX_INT64_STR = string(typemax(Int))
const TYPEMAX_INT128_STR = string(typemax(Int128))
function Expr_int(x)
    is_hex = is_oct = is_bin = false
    val = replace(valof(x), "_" => "")
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
    if !startswith(valof(x), "0x") && 'f' in valof(x)
        return Base.parse(Float32, replace(valof(x), 'f' => 'e'))
    end
    Base.parse(Float64, replace(valof(x), "_" => ""))
end
function Expr_char(x)
    val = _unescape_string(valof(x)[2:prevind(valof(x), lastindex(valof(x)))])
    # one byte e.g. '\xff' maybe not valid UTF-8
    # but we want to use the raw value as a codepoint in this case
    sizeof(val) == 1 && return Char(codeunit(val, 1))
    length(val) == 1 || error("Invalid character literal: $(Vector{UInt8}(valof(x)))")
    val[1]
end


# Expressions

# Fallback
function Expr(x::EXPR)
    if isidentifier(x)
        if headof(x) === :NonStdIdentifier
            Symbol(normalize_julia_identifier(valof(x.args[2])))
        else
            return Symbol(normalize_julia_identifier(valof(x)))
        end
    elseif iskeyword(x)
        if headof(x) === :break
            return Expr(:break)
        elseif headof(x) === :continue
            return Expr(:continue)
        else
            return Symbol(lowercase(string(headof(x))))
        end
    elseif isoperator(x)
        return Symbol(valof(x))
    elseif ispunctuation(x)
        return string(kindof(x))
    elseif isliteral(x)
        return _literal_expr(x)
    elseif x.head === :Brackets
        return Expr(x.args[1])
    elseif x.head isa EXPR
        Expr(Expr(x.head), Expr.(x.args)...)
    elseif x.head === :Quotenode
        QuoteNode(Expr(x.args[1]))
    elseif x.head === :MacroName
        Symbol("@", x.args[2].val)
    elseif x.head === :x_Cmd
        Expr(:macrocall, Symbol("@", Expr(x.args[1]), "_cmd"), nothing, valof(x.args[2]))
    elseif x.head === :x_Str
        Expr(:macrocall, Symbol("@", Expr(x.args[1]), "_str"), nothing, valof(x.args[2]))
    elseif x.head === :GlobalRefDoc
        GlobalRef(Core, :(var"@doc"))
    else
        Expr(Symbol(lowercase(String(x.head))), Expr.(x.args)...)
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
    if issyntaxcall(x.args[2]) && !(valof(x[2]) == ":")
        if valof(x[2]) == "."
            arg1, arg2 = Expr(x.args[1]), Expr(x.args[3])
            if arg2 isa Expr && arg2.head === :macrocall && endswith(string(arg2.args[1]), "_cmd")
                return Expr(:macrocall, Expr(:., arg1, QuoteNode(arg2.args[1])), nothing, arg2.args[3])
            elseif arg2 isa Expr && arg2.head === :braces
                return Expr(:., arg1, Expr(:quote, arg2))
            end
        end
        Expr(Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
    else
        Expr(:call, Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
    end
end

function _where_expr(x)
    ret = Expr(:where, Expr(x.args[1]))
    for i = 3:length(x.args)
        a = x.args[i]
        if headof(a) === :Parameters
            insert!(ret.args, 2, Expr(a))
        elseif !(ispunctuation(a) || iskeyword(a))
            push!(ret.args, Expr(a))
        end
    end
    return ret
end


# cross compatability for line number insertion in macrocalls
if VERSION > v"1.1-"
    Expr_cmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, valof(x))
    Expr_tcmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, valof(x))
else
    Expr_cmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, valof(x))
    Expr_tcmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, valof(x))
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
        if x.head == :macrocall && x.args[2] !== nothing
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
        if iskeyword(a) && headof(a) === :elseif
            i += 1
            r1 = Expr(x.args[i].args[1])
            push!(ret.args, Expr(:elseif, r1.args...))
        elseif !(ispunctuation(a) || iskeyword(a))
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
    elseif headof(x.args[2]) === :Block
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
    if isbinarycall(a) && (is_in(a.args[2]) || is_elof(a.args[2]))
        Expr(:(=), Expr(a.args[1]), Expr(a.args[3]))
    else
        Expr(a)
    end
end

function get_inner_gen(x, iters = [], arg = [])
    if headof(x) == :Flatten
        get_inner_gen(x.args[1], iters, arg)
    elseif headof(x) === :Generator
        # push!(iters, get_iter(x))
        get_iters(x, iters)
        if headof(x.args[1]) === :Generator || headof(x.args[1]) === :Flatten
            get_inner_gen(x.args[1], iters, arg)
        else
            push!(arg, x.args[1])
        end
    end
    return iters, arg
end

function get_iter(x)
    if headof(x) === :Generator
        return x.args[3]
    end
end

function get_iters(x, iters)
    iters1 = []
    if headof(x) === :Generator

        for i = 3:length(x.args)
            if !ispunctuation(x.args[i])
                push!(iters1, x.args[i])
            end
        end
    end
    push!(iters, iters1)
end

function convert_iter_assign(a)
    if isbinarycall(a) && (is_in(a.args[2]) || is_elof(a.args[2]))
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
    col = findall(a->isoperator(a) && valof(a) == ":", x.args)
    comma = findall(is_comma, x.args)

    header = []
    args = [Expr(:.)]
    i = 1 # skip keyword
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

