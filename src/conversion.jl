import Base: Expr

function Expr(x::EXPR)
    ret = Expr(:call)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{TopLevel})
    ret = Expr(:toplevel)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end
# Expr(x::HEAD{Tokens.LBRACE}) = :cell1d
Expr(x::HEAD{T}) where {T} = Symbol(lowercase(string(T)))
Expr(x::KEYWORD{T}) where {T} = Symbol(lowercase(string(T)))

function julia_normalization_map(c::Int32, x::Ptr{Void})::Int32
    return c == 0x00B5 ? 0x03BC : # micro sign -> greek small letter mu
           c == 0x025B ? 0x03B5 : # latin small letter open e -> greek small letter
           c
end

# Note: This code should be in julia base
function utf8proc_map_custom(str::String, options, func)
    norm_func = cfunction(func, Int32, (Int32, Ptr{Void}))
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Void}, Ptr{Void}),
                   str, sizeof(str), C_NULL, 0, options, norm_func, C_NULL)
    nwords < 0 && Base.UTF8proc.utf8proc_error(nwords)
    buffer = Base.StringVector(nwords*4)
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Void}, Ptr{Void}),
                   str, sizeof(str), buffer, nwords, options, norm_func, C_NULL)
    nwords < 0 && Base.UTF8proc.utf8proc_error(nwords)
    nbytes = ccall(:utf8proc_reencode, Int, (Ptr{UInt8}, Int, Cint), buffer, nwords, options)
    nbytes < 0 && Base.UTF8proc.utf8proc_error(nbytes)
    return String(resize!(buffer, nbytes))
end

function normalize_julia_identifier(str::AbstractString)
    options = Base.UTF8proc.UTF8PROC_STABLE | Base.UTF8proc.UTF8PROC_COMPOSE
    utf8proc_map_custom(String(str), options, julia_normalization_map)
end

Expr(x::EXPR{IDENTIFIER}) = Symbol(normalize_julia_identifier(x.val))

function Expr(x::EXPR{OPERATOR{O,K,dot}}) where {O, K, dot}
    if dot
        Symbol(:., UNICODE_OPS_REVERSE[K])
    else
        UNICODE_OPS_REVERSE[K]
    end
end

Expr(x::EXPR{LITERAL{Tokens.TRUE}}) = true
Expr(x::EXPR{LITERAL{Tokens.FALSE}}) = false
function Expr(x::EXPR{HEAD{:nothing}}) end

function sized_uint_literal(s::AbstractString, b::Integer)
    # We know integers are all ASCII, so we can use sizeof to compute
    # the length of ths string more quickly
    l = (sizeof(s) - 2) * b
    l <= 8   && return Base.parse(UInt8,   s)
    l <= 16  && return Base.parse(UInt16,  s)
    l <= 32  && return Base.parse(UInt32,  s)
    l <= 64  && return Base.parse(UInt64,  s)
    l <= 128 && return Base.parse(UInt128, s)
    return Base.parse(BigInt,s)
end

function sized_uint_oct_literal(s::AbstractString)
    s[3] == 0 && return sized_uint_literal(s, 3)
    len = sizeof(s)
    (len < 5  || (len == 5  && s <= "0o377")) && return Base.parse(UInt8,s)
    (len < 8  || (len == 8  && s <= "0o177777")) && return Base.parse(UInt16, s)
    (len < 13 || (len == 13 && s <= "0o37777777777")) && return Base.parse(UInt32,s)
    (len < 24 || (len == 24 && s <= "0o1777777777777777777777")) && return Base.parse(UInt64,s)
    (len < 45 || (len == 45 && s <= "0o3777777777777777777777777777777777777777777")) && return Base.parse(UInt128,s)
    return Base.parse(BigInt,s)
end

const TYPEMAX_INT64_STR = string(typemax(Int))
const TYPEMAX_INT128_STR = string(typemax(Int128))
function Expr(x::EXPR{LITERAL{Tokens.INTEGER}})
    is_hex = is_oct = is_bin = false
    val = replace(x.val, "_", "")
    if sizeof(val) > 2 && val[1] == '0'
        c = val[2]
        c == 'x' && (is_hex = true)
        c == 'o' && (is_oct = true)
        c == 'b' && (is_bin = true)
    end
    is_hex && return sized_uint_literal(val, 4)
    is_oct && return sized_uint_oct_literal(val)
    is_bin && return sized_uint_literal(val, 1)
    sizeof(val) < sizeof(TYPEMAX_INT64_STR) && return Base.parse(Int64, val)
    val < TYPEMAX_INT64_STR && return Base.parse(Int64, val)
    sizeof(val) < sizeof(TYPEMAX_INT128_STR) && return Base.parse(Int128, val)
    val < TYPEMAX_INT128_STR && return Base.parse(Int128, val)
    Base.parse(BigInt, val)
end

function Expr(x::EXPR{LITERAL{Tokens.FLOAT}})
    if 'f' in x.val
        return Base.parse(Float32, replace(x.val, 'f', 'e'))
    end
    Base.parse(Float64, x.val)
end
function Expr(x::EXPR{LITERAL{Tokens.CHAR}})
    val = Base.unescape_string(x.val[2:end-1])
    # one byte e.g. '\xff' maybe not valid UTF-8
    # but we want to use the raw value as a codepoint in this case
    sizeof(val) == 1 && return Char(Vector{UInt8}(val)[1])
    length(val) == 1 || error("Invalid character literal")
    val[1]
end
Expr(x::EXPR{LITERAL{Tokens.MACRO}}) = Symbol(x.val)
Expr(x::EXPR{LITERAL{Tokens.STRING}}) = x.val
Expr(x::EXPR{LITERAL{Tokens.TRIPLE_STRING}}) = x.val

# cross compatability for line number insertion in macrocalls
@static if VERSION < v"0.7.0-DEV.357"
    Expr(x::EXPR{LITERAL{Tokens.CMD}}) = Expr(:macrocall, Symbol("@cmd"), x.val)
    Expr(x::EXPR{LITERAL{Tokens.TRIPLE_CMD}}) = Expr(:macrocall, Symbol("@cmd"), x.val)

    function Expr(x::EXPR{x_Str})
        if x.args[1] isa EXPR{BinarySyntaxOpCall}
            mname = Expr(x.args[1])
            mname.args[2] = QuoteNode(Symbol("@", mname.args[2].value, "_str"))
            ret = Expr(:macrocall, mname)
        else
            ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_str"))
        end
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    end

    function Expr(x::EXPR{x_Cmd})
        ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"))
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    end

    function Expr(x::EXPR{MacroCall})
        ret = Expr(:macrocall)
        for a in x.args
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                push!(ret.args, Expr(a))
            end
        end
        ret
    end

    """
        remlineinfo!(x)
    Removes line info expressions. (i.e. Expr(:line, 1))
    """
    function remlineinfo!(x)
        if isa(x, Expr)
            id = find(map(x -> (isa(x, Expr) && x.head == :line) || (isdefined(:LineNumberNode) && x isa LineNumberNode), x.args))
            deleteat!(x.args, id)
            for j in x.args
                remlineinfo!(j)
            end
        end
        x
    end
else
    Expr(x::EXPR{LITERAL{Tokens.CMD}}) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
    Expr(x::EXPR{LITERAL{Tokens.TRIPLE_CMD}}) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)

    function Expr(x::EXPR{x_Str})
        if x.args[1] isa EXPR{BinarySyntaxOpCall}
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
    end

    function Expr(x::EXPR{x_Cmd})
        ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"), nothing)
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    end

    function Expr(x::EXPR{MacroCall})
        ret = Expr(:macrocall)
        for a in x.args
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                push!(ret.args, Expr(a))
            end
        end
        insert!(ret.args, 2, nothing)
        ret
    end
    """
        remlineinfo!(x)
    Removes line info expressions. (i.e. Expr(:line, 1))
    """
    function remlineinfo!(x)
        if isa(x, Expr)
            if x.head == :macrocall && x.args[2] != nothing
                id = find(map(x -> (isa(x, Expr) && x.head == :line) || (isdefined(:LineNumberNode) && x isa LineNumberNode), x.args))
                deleteat!(x.args, id)
                for j in x.args
                    remlineinfo!(j)
                end
                insert!(x.args, 2, nothing)
            else
                id = find(map(x -> (isa(x, Expr) && x.head == :line) || (isdefined(:LineNumberNode) && x isa LineNumberNode), x.args))
                deleteat!(x.args, id)
                for j in x.args
                    remlineinfo!(j)
                end
            end
        end
        x
    end
end


Expr(x::EXPR{PUNCTUATION{K}}) where {K} = string(K)

Expr(x::EXPR{Quotenode}) = QuoteNode(Expr(x.args[end]))
Expr(x::EXPR{KEYWORD{t}}) where t = Symbol(lowercase(string(t)))

function Expr(x::EXPR{Call})
    ret = Expr(:call)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Comparison})
    ret = Expr(:comparison)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{ChainOpCall})
    ret = Expr(:call, Expr(x.args[2]))
    for i = 1:length(x.args)
        if isodd(i)
            push!(ret.args, Expr(x.args[i]))
        end
    end
    ret
end

Expr(x::EXPR{BinaryOpCall}) = Expr(:call, Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))

function Expr(x::EXPR{BinarySyntaxOpCall})
    if x.args[2] isa EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}}
        ret = Expr(:where, Expr(x.args[1]))
        for i = 3:length(x.args)
            a = x.args[i]
            if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
                push!(ret.args, Expr(a))
            end
        end
    else
        ret = Expr(Expr(x.args[2]), Expr(x.args[1]), Expr(x.args[3]))
    end
    return ret
end


Expr(x::EXPR{ConditionalOpCall}) = Expr(:if, Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))

Expr(x::EXPR{ColonOpCall}) = Expr(:(:), Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))

function Expr(x::EXPR{UnarySyntaxOpCall})
    if x.args[1] isa EXPR{OP} where OP <: OPERATOR
        return Expr(Expr(x.args[1]), Expr(x.args[2]))
    else
        return Expr(Expr(x.args[2]), Expr(x.args[1]))
    end
end

function Expr(x::EXPR{UnaryOpCall})
    return Expr(:call, Expr(x.args[1]), Expr(x.args[2]))
end


Expr(x::EXPR{Struct}) = Expr(:type, false, Expr(x.args[2]), Expr(x.args[3]))

Expr(x::EXPR{Mutable}) = length(x.args) == 4 ? Expr(:type, true, Expr(x.args[2]), Expr(x.args[3])) : Expr(:type, true, Expr(x.args[3]), Expr(x.args[4]))

Expr(x::EXPR{Abstract}) = length(x.args) == 2 ? Expr(:abstract, Expr(x.args[2])) : Expr(:abstract, Expr(x.args[3]))
Expr(x::EXPR{Bitstype}) = Expr(:bitstype, Expr(x.args[2]), Expr(x.args[3]))
Expr(x::EXPR{Primitive}) = Expr(:bitstype, Expr(x.args[4]), Expr(x.args[3]))
Expr(x::EXPR{TypeAlias}) = Expr(:typealias, Expr(x.args[2]), Expr(x.args[3]))


function Expr(x::EXPR{Block})
    ret = Expr(:block)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

function Expr(x::EXPR{TupleH})
    ret = Expr(:tuple)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 1, Expr(a))
        elseif !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

Expr(x::EXPR{Kw}) = Expr(:kw, Expr(x.args[1]), Expr(x.args[3]))

function Expr(x::EXPR{Parameters})
    ret = Expr(:parameters)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

Expr(x::EXPR{InvisBrackets}) = Expr(x.args[2])
Expr(x::EXPR{Begin}) = Expr(x.args[2])

function Expr(x::EXPR{Quote})
    if x.args[2] isa EXPR{InvisBrackets} && (x.args[2].args[2] isa EXPR{OP} where OP <: OPERATOR|| x.args[2].args[2] isa EXPR{L} where L <: LITERAL || x.args[2].args[2] isa EXPR{IDENTIFIER})
        return QuoteNode(Expr(x.args[2]))
    else
        return Expr(:quote, Expr(x.args[2]))
    end
end


function Expr(x::EXPR{If})
    ret = Expr(:if)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{FunctionDef})
    ret = Expr(:function)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Try})
    ret = Expr(:try)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Let})
    ret = Expr(:let, Expr(x.args[end - 1]))
    for i = 1:length(x.args) - 2
        a = x.args[i]
        if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Do})
    ret = Expr(x.args[1])
    insert!(ret.args, 2, Expr(:->, Expr(x.args[3]), Expr(x.args[4])))
    ret
end

fix_range(a) = Expr(a)
function fix_range(a::EXPR{BinaryOpCall})
    if (a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}})
        Expr(:(=), Expr(a.args[1]), Expr(a.args[3]))
    else
        Expr(a)
    end
end

function Expr(x::EXPR{For})
    ret = Expr(:for)
    if x.args[2] isa EXPR{Block}
        arg = Expr(:block)
        for a in x.args[2].args
            if !(a isa EXPR{P} where P <: PUNCTUATION)
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

function Expr(x::EXPR{While})
    ret = Expr(:while)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION || a isa EXPR{K} where K <: KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Return})
    ret = Expr(:return)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr(x::EXPR{Global})
    ret = Expr(:global)
    if x.args[2] isa EXPR{Const}
        ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
    elseif length(x.args) == 2 && x.args[2] isa EXPR{TupleH}
        for a in x.args[2].args
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                push!(ret.args, Expr(a))
            end
        end
    else
        for i = 2:length(x.args)
            a = x.args[i]
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Local})
    ret = Expr(:local)
    if x.args[2] isa EXPR{Const}
        ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
    elseif length(x.args) == 2 && x.args[2] isa EXPR{TupleH}
        for a in x.args[2].args
            if !(a isa EXPR{P} where P <: PUNCTUATION)
                push!(ret.args, Expr(a))
            end
        end
    else
        for i = 2:length(x.args)
            a = x.args[i]
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Const})
    ret = Expr(:const)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end
Expr(x::EXPR{Break}) = Expr(:break)
Expr(x::EXPR{Continue}) = Expr(:continue)



function Expr(x::EXPR{Curly})
    ret = Expr(:curly)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Vect})
    ret = Expr(:vect)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Macro})
    Expr(:macro, Expr(x.args[2]), Expr(x.args[3]))
end

Expr(x::EXPR{HEAD{:globalrefdoc}}) = GlobalRef(Core, Symbol("@doc"))

function Expr(x::EXPR{Row})
    ret = Expr(:row)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Hcat})
    ret = Expr(:hcat)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Vcat})
    ret = Expr(:vcat)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Ref})
    ret = Expr(:ref)
    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{TypedHcat})
    ret = Expr(:typed_hcat)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{TypedVcat})
    ret = Expr(:typed_vcat)

    for a in x.args
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr(x::EXPR{Comprehension})
    ret = Expr(:comprehension)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end
# NEEDS FIX (only works for 2 levels )
function Expr(x::EXPR{Flatten})
    ret = Expr(:flatten, Expr(x.args[1]))

    gen1 = ret.args[1].args[1].args[2]
    gen2 = ret.args[1].args[2]
    ret.args[1].args[1].args[2] = gen2
    ret.args[1].args[2] = gen1
    return ret
end

function Expr(x::EXPR{Generator})
    ret = Expr(:generator, Expr(x.args[1]))
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            if a isa EXPR{BinaryOpCall} && (a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}})
                push!(ret.args, Expr(:(=), Expr(a.args[1]), Expr(a.args[3])))
            else
                push!(ret.args, Expr(a))
            end
        end
    end
    ret
end

function Expr(x::EXPR{Filter})
    ret = Expr(:filter)
    for a in x.args
        if !(a isa EXPR{KEYWORD{Tokens.IF}})
            if a isa EXPR{BinaryOpCall} && (a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || a.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}})
                push!(ret.args, Expr(:(=), Expr(a.args[1]), Expr(a.args[3])))
            else
                push!(ret.args, Expr(a))
            end
        end
    end
    ret
end




function Expr(x::EXPR{TypedComprehension})
    ret = Expr(:typed_comprehension)
    for a in x.args
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function Expr(x::EXPR{Export})
    ret = Expr(:export)
    for i = 2:length(x.args)
        a = x.args[i]
        if !(a isa EXPR{P} where P <: PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

Expr(x::EXPR{ModuleH}) = Expr(:module, true, Expr(x.args[2]), Expr(x.args[3]))
Expr(x::EXPR{BareModule}) = Expr(:module, false, Expr(x.args[2]), Expr(x.args[3]))




function _get_import_block(x, i, ret)
    while x.args[i + 1] isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}}
        i += 1
        push!(ret.args, :.)
    end
    while i < length(x.args) && !(x.args[i + 1] isa EXPR{PUNCTUATION{Tokens.COMMA}})
        i += 1
        a = x.args[i]
        if !(a isa EXPR{P} where P <: PUNCTUATION) && !(a isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}} || a isa EXPR{OPERATOR{ColonOp,Tokens.COLON,false}})
            push!(ret.args, Expr(a))
        end
    end

    return i
end


Expr(x::EXPR{Import}) = expr_import(x, :import)
Expr(x::EXPR{ImportAll}) = expr_import(x, :importall)
Expr(x::EXPR{Using}) = expr_import(x, :using)

function expr_import(x, kw)
    col = find(a isa EXPR{o} where o <: OPERATOR{ColonOp} for a in x.args)
    comma = find(a isa EXPR{PUNCTUATION{Tokens.COMMA}} for a in x.args)
    if isempty(comma)
        ret = Expr(kw)
        i = 1
        _get_import_block(x, i, ret)
    elseif isempty(col)
        ret = Expr(:toplevel)
        i = 1
        while i < length(x.args)
            nextarg = Expr(kw)
            i = _get_import_block(x, i, nextarg)
            if i < length(x.args) && (x.args[i + 1] isa EXPR{PUNCTUATION{Tokens.COMMA}})
                i += 1
            end
            push!(ret.args, nextarg)
        end
    else
        ret = Expr(:toplevel)
        top = Expr(kw)
        i = 1
        while x.args[i + 1] isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}}
            i += 1
            push!(top.args, :.)
        end
        while i < length(x.args) && !(x.args[i + 1] isa EXPR{o} where o <: OPERATOR{ColonOp})
            i += 1
            a = x.args[i]
            if !(a isa EXPR{P} where P <: PUNCTUATION) && !(a isa EXPR{OPERATOR{DotOp,Tokens.DOT,false}} || a isa EXPR{OPERATOR{ColonOp,Tokens.COLON,false}})
                push!(top.args, Expr(a))
            end
        end
        while i < length(x.args)
            nextarg = Expr(kw, top.args...)
            i = _get_import_block(x, i, nextarg)
            if i < length(x.args) && (x.args[i + 1] isa EXPR{PUNCTUATION{Tokens.COMMA}})
                i += 1
            end
            push!(ret.args, nextarg)
        end
    end
    return ret
end

function Expr(x::EXPR{FileH})
    ret = Expr(:file)
    for a in x.args
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr(x::EXPR{StringH})
    ret = Expr(:string)
    for (i,a) in enumerate(x.args)
        if typeof(a) == EXPR{UnarySyntaxOpCall}
            a = a.args[2]
        elseif typeof(a) == EXPR{LITERAL{Tokens.STRING}}
            if span(a) == 0 || ((i == 1 || i == length(x.args)) && span(a) == 1) || isempty(a.val)
                continue
            end
        end
        push!(ret.args, Expr(a))
    end
    ret
end

UNICODE_OPS_REVERSE = Dict{Tokenize.Tokens.Kind,Symbol}()
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
