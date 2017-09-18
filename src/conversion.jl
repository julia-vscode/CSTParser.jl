import Base: Expr

# Terminals
Expr(x::IDENTIFIER) = Symbol(normalize_julia_identifier(x.val))
Expr(x::KEYWORD{T}) where {T} = Symbol(lowercase(string(T)))
Expr(x::KEYWORD{Tokens.BREAK}) = Expr(:break)
Expr(x::KEYWORD{Tokens.CONTINUE}) = Expr(:continue)
Expr(x::OPERATOR) = x.dot ? Symbol(:., UNICODE_OPS_REVERSE[x.kind]) : UNICODE_OPS_REVERSE[x.kind]
Expr(x::PUNCTUATION)= string(x.kind)

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
    buffer = Base.StringVector(nwords * 4)
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


function sized_uint_literal(s::AbstractString, b::Integer)
    # We know integers are all ASCII, so we can use sizeof to compute
    # the length of ths string more quickly
    l = (sizeof(s) - 2) * b
    l <= 8   && return Base.parse(UInt8,   s)
    l <= 16  && return Base.parse(UInt16,  s)
    l <= 32  && return Base.parse(UInt32,  s)
    l <= 64  && return Base.parse(UInt64,  s)
    l <= 128 && return Base.parse(UInt128, s)
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

function Expr(x::LITERAL)
    if x.kind == Tokens.TRUE
        return true
    elseif x.kind == Tokens.FALSE
        return false
    elseif is_nothing(x)
        return nothing
    elseif x.kind == Tokens.INTEGER
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

function Expr_float(x)
    if 'f' in x.val
        return Base.parse(Float32, replace(x.val, 'f', 'e'))
    end
    Base.parse(Float64, x.val)
end
function Expr_char(x)
    val = Base.unescape_string(x.val[2:end - 1])
    # one byte e.g. '\xff' maybe not valid UTF-8
    # but we want to use the raw value as a codepoint in this case
    sizeof(val) == 1 && return Char(Vector{UInt8}(val)[1])
    length(val) == 1 || error("Invalid character literal")
    val[1]
end


# Expressions

@eval begin
    if_exprs = Expr(:block)
    for head in [ChainOpCall, Comparison, ColonOpCall, TopLevel, MacroName, x_Str,
                 x_Cmd, MacroCall, QuoteNode, Call, Struct, Mutable, Abstract, Bitstype,
                 Primitive, TypeAlias, FunctionDef, Macro, ModuleH, BareModule, If,
                 Try, Let, Do, For, While, TupleH, Curly, Vect, Row, Hcat, Vcat, Kw,
                 Return, InvisBrackets, Global, Local, Const, GlobalRefDoc, Ref, TypedHcat,
                 TypedVcat, Comprehension, Flatten, Generator, Filter, TypedComprehension, Export,
                 Import, ImportAll, Using, FileH, StringH]
        # x.head == $(head) && return Expr_$(head)
        push!(if_exprs.args, :(x.head == $head && return $(Symbol("Expr_" * string(head)))))
    end
    quote
        function Expr(x::EXPR)
            $(if_exprs)
            # Fallback
            ret = Expr(:call)
            for a in x.args
                if !(a isa PUNCTUATION)
                    push!(ret.args, Expr(a))
                end
            end
            ret
        end
    end
end

# Op. expressions
Expr(x::UnaryOpCall) = Expr(:call, Expr(x.op), Expr(x.arg))
Expr(x::UnarySyntaxOpCall) = x.arg1 isa OPERATOR ? Expr(Expr(x.arg1), Expr(x.arg2)) : Expr(Expr(x.arg2), Expr(x.arg1))
Expr(x::BinaryOpCall) = Expr(:call, Expr(x.op), Expr(x.arg1), Expr(x.arg2))
Expr(x::BinarySyntaxOpCall) = Expr(Expr(x.op), Expr(x.arg1), Expr(x.arg2))
Expr(x::ConditionalOpCall) = Expr(:if, Expr(x.cond), Expr(x.arg1), Expr(x.arg2))
function Expr_ChainOpCall(x::EXPR)
    ret = Expr(:call, Expr(x.args[2]))
    for i = 1:length(x.args)
        if isodd(i)
            push!(ret.args, Expr(x.args[i]))
        end
    end
    ret
end
function Expr_Comparison(x::EXPR)
    ret = Expr(:comparison)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end
Expr_ColonOpCall(x::EXPR) = Expr(:(:), Expr(x.args[1]), Expr(x.args[3]), Expr(x.args[5]))


function Expr(x::WhereOpCall)
    ret = Expr(:where, Expr(x.arg1))
    for i = 1:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

function Expr_TopLevel(x::EXPR)
    ret = Expr(:toplevel)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_MacroName(x::EXPR)
    if x.args[2] isa IDENTIFIER
        return Symbol("@", x.args[2].val)
    end
end

# cross compatability for line number insertion in macrocalls
@static if VERSION < v"0.7.0-DEV.357"
    Expr_cmd(x) = Expr(:macrocall, Symbol("@cmd"), x.val)
    Expr_tcmd(x) = Expr(:macrocall, Symbol("@cmd"), x.val)

    function Expr_x_Str(x::EXPR)
        if x.args[1] isa BinarySyntaxOpCall
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

    function Expr_x_Cmd(x::EXPR)
        ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"))
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    end

    function Expr_MacroCall(x::EXPR)
        ret = Expr(:macrocall)
        for a in x.args
            if !(a isa PUNCTUATION)
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
    Expr_cmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
    Expr_tcmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)

    function Expr_x_Str(x::EXPR)
        if x.args[1] isa BinarySyntaxOpCall
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

    function Expr_x_Cmd(x::EXPR)
        ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"), nothing)
        for i = 2:length(x.args)
            push!(ret.args, x.args[i].val)
        end
        return ret
    end

    function Expr_MacroCall(x::EXPR)
        ret = Expr(:macrocall)
        for a in x.args
            if !(a isa PUNCTUATION)
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

Expr_QuoteNode(x::EXPR) = QuoteNode(Expr(x.args[end]))

function Expr_Call(x::EXPR)
    ret = Expr(:call)
    for a in x.args
        if is_parameters(a)
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

# Definitiions
Expr_Struct(x::EXPR) = Expr(:type, false, Expr(x.args[2]), Expr(x.args[3]))
Expr_Mutable(x::EXPR) = length(x.args) == 4 ? Expr(:type, true, Expr(x.args[2]), Expr(x.args[3])) : Expr(:type, true, Expr(x.args[3]), Expr(x.args[4]))
Expr_Abstract(x::EXPR) = length(x.args) == 2 ? Expr(:abstract, Expr(x.args[2])) : Expr(:abstract, Expr(x.args[3]))
Expr_Bitstype(x::EXPR) = Expr(:bitstype, Expr(x.args[2]), Expr(x.args[3]))
Expr_Primitive(x::EXPR) = Expr(:bitstype, Expr(x.args[4]), Expr(x.args[3]))
Expr_TypeAlias(x::EXPR) = Expr(:typealias, Expr(x.args[2]), Expr(x.args[3]))

function Expr_FunctionDef(x::EXPR)
    ret = Expr(:function)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end
Expr_Macro(x::EXPR) = Expr(:macro, Expr(x.args[2]), Expr(x.args[3]))
Expr_ModuleH(x::EXPR) = Expr(:module, true, Expr(x.args[2]), Expr(x.args[3]))
Expr_BareModule(x::EXPR) = Expr(:module, false, Expr(x.args[2]), Expr(x.args[3]))



# Control Flow

function Expr_If(x::EXPR)
    ret = Expr(:if)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Try(x::EXPR)
    ret = Expr(:try)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Let(x::EXPR)
    ret = Expr(:let, Expr(x.args[end - 1]))
    for i = 1:length(x.args) - 2
        a = x.args[i]
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Do(x::EXPR)
    ret = Expr(x.args[1])
    insert!(ret.args, 2, Expr(:->, Expr(x.args[3]), Expr(x.args[4])))
    ret
end


# Loops

function Expr_For(x::EXPR)
    ret = Expr(:for)
    if is_block(x.args[2])
        arg = Expr(:block)
        for a in x.args[2].args
            if !(a isa PUNCTUATION)
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

function Expr_While(x::EXPR)
    ret = Expr(:while)
    for a in x.args
        if !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


fix_range(a) = Expr(a)
function fix_range(a::BinaryOpCall)
    if (is_in(a.op) || is_elof(a.op))
        Expr(:(=), Expr(a.arg1), Expr(a.arg2))
    else
        Expr(a)
    end
end




# Lists

function Expr_TupleH(x::EXPR)
    ret = Expr(:tuple)
    for a in x.args
        if is_parameters(a)
            insert!(ret.args, 1, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

function Expr_Curly(x::EXPR)
    ret = Expr(:curly)
    for a in x.args
        if is_parameters(a)
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Vect(x::EXPR)
    ret = Expr(:vect)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Row(x::EXPR)
    ret = Expr(:row)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Hcat(x::EXPR)
    ret = Expr(:hcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Vcat(x::EXPR)
    ret = Expr(:vcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Block(x::EXPR)
    ret = Expr(:block)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end


Expr_Kw(x::EXPR) = Expr(:kw, Expr(x.args[1]), Expr(x.args[3]))

function Expr_Parameters(x::EXPR)
    ret = Expr(:parameters)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    return ret
end

function Expr_Return(x::EXPR)
    ret = Expr(:return)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end

Expr_InvisBrackets(x::EXPR) = Expr(x.args[2])
Expr_Begin(x::EXPR) = Expr(x.args[2])

function Expr_Quote(x::EXPR)
    if is_invisbrackets(x.args[2]) && (x.args[2].args[2] isa OPERATOR || x.args[2].args[2] isa LITERAL || x.args[2].args[2] isa IDENTIFIER)
        return QuoteNode(Expr(x.args[2]))
    else
        return Expr(:quote, Expr(x.args[2]))
    end
end

function Expr_Global(x::EXPR)
    ret = Expr(:global)
    if is_const(x.args[2])
        ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
    elseif length(x.args) == 2 && is_tupleh(x.args[2])
        for a in x.args[2].args
            if !(a isa PUNCTUATION)
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

function Expr_Local(x::EXPR)
    ret = Expr(:local)
    if is_const(x.args[2])
        ret = Expr(:const, Expr(:global, Expr(x.args[2].args[2])))
    elseif length(x.args) == 2 && is_tupleh(x.args[2])
        for a in x.args[2].args
            if !(a isa PUNCTUATION)
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

function Expr_Const(x::EXPR)
    ret = Expr(:const)
    for i = 2:length(x.args)
        a = x.args[i]
        push!(ret.args, Expr(a))
    end
    ret
end


Expr_GlobalRefDoc(x::EXPR) = GlobalRef(Core, Symbol("@doc"))



function Expr_Ref(x::EXPR)
    ret = Expr(:ref)
    for a in x.args
        if is_parameters(a)
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_TypedHcat(x::EXPR)
    ret = Expr(:typed_hcat)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_TypedVcat(x::EXPR)
    ret = Expr(:typed_vcat)

    for a in x.args
        if is_parameters(a)
            insert!(ret.args, 2, Expr(a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Comprehension(x::EXPR)
    ret = Expr(:comprehension)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Flatten(x::EXPR)
    iters, args = get_inner_gen(x)
    i = shift!(iters)
    ex = Expr(:generator, Expr(args[1]), convert_iter_assign(i))
    for i in iters
        ex = Expr(:generator, ex, convert_iter_assign(i))
        ex = Expr(:flatten, ex)
    end
    # ret = Expr(:flatten, ex)

    return ex
end


function get_inner_gen(x, iters = [], arg = [])
    if is_flatten(x)
        return getinner_gen_flatten(x, iters, arg)
    elseif is_generator(x)
        return get_inner_gen_generator(x.args[1], iters, arg)
    end
    return iters, arg
end
function get_inner_gen_flatten(x::EXPR, iters = [], arg = [])
    get_inner_gen(x.args[1], iters, arg)
    iters, arg
end
function get_inner_gen_generator(x::EXPR, iters = [], arg = [])
    push!(iters, get_iter(x))
    if is_generator(x.args[1]) || is_flatten(x.args[1])
        get_inner_gen(x.args[1], iters, arg)
    else
        push!(arg, x.args[1])
    end
    iters, arg
end

function get_iter(x::EXPR)
    is_generator(x) && return x.args[3]
    unhandled_head(x.head)
end

function Expr_Generator(x::EXPR)
    ret = Expr(:generator, Expr(x.args[1]))
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_iter_assign(a))
        end
    end
    ret
end

function Expr_Filter(x::EXPR)
    ret = Expr(:filter)
    for a in x.args
        if !(a isa KEYWORD{Tokens.IF} || a isa PUNCTUATION)
            push!(ret.args, convert_iter_assign(a))
        end
    end
    ret
end

function convert_iter_assign(a)
    if a isa BinaryOpCall && (is_in(a.op) || is_elof(a.op))
        return Expr(:(=), Expr(a.arg1), Expr(a.arg2))
    else
        return Expr(a)
    end
end

function Expr_TypedComprehension(x::EXPR)
    ret = Expr(:typed_comprehension)
    for a in x.args
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end

function Expr_Export(x::EXPR)
    ret = Expr(:export)
    for i = 2:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            push!(ret.args, Expr(a))
        end
    end
    ret
end


function _get_import_block(x, i, ret)
    while is_dot(x.args[i + 1])
        i += 1
        push!(ret.args, :.)
    end
    while i < length(x.args) && !(is_comma(x.args[i + 1]))
        i += 1
        a = x.args[i]
        if !(a isa PUNCTUATION) && !(is_dot(a) || is_colon(a))
            push!(ret.args, Expr(a))
        end
    end

    return i
end


Expr_Import(x::EXPR) = expr_import(x, :import)
Expr_Importall(x::EXPR) = expr_import(x, :importall)
Expr_Using(x::EXPR) = expr_import(x, :using)

function expr_import(x, kw)
    col = find(a isa OPERATOR && precedence(a) == ColonOp for a in x.args)

    comma = find(is_comma(a) for a in x.args)
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
            if i < length(x.args) && is_comma(x.args[i + 1])
                i += 1
            end
            push!(ret.args, nextarg)
        end
    else
        ret = Expr(:toplevel)
        top = Expr(kw)
        i = 1
        while is_dot(x.args[i + 1])
            i += 1
            push!(top.args, :.)
        end
        while i < length(x.args) && !(x.args[i + 1] isa OPERATOR && precedence(x.args[i+1]) == ColonOp)
            i += 1
            a = x.args[i]
            if !(a isa PUNCTUATION) && !(is_dot(a) || is_colon(a))
                push!(top.args, Expr(a))
            end
        end
        while i < length(x.args)
            nextarg = Expr(kw, top.args...)
            i = _get_import_block(x, i, nextarg)
            if i < length(x.args) && (is_comma(x.args[i + 1]))
                i += 1
            end
            push!(ret.args, nextarg)
        end
    end
    return ret
end

function Expr_FileH(x::EXPR)
    ret = Expr(:file)
    for a in x.args
        push!(ret.args, Expr(a))
    end
    ret
end

function Expr_StringH(x::EXPR)
    ret = Expr(:string)
    for (i, a) in enumerate(x.args)
        if a isa UnarySyntaxOpCall
            a = a.arg2
        elseif a isa LITERAL && a.kind == Tokens.STRING
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
