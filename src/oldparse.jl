# Type Declarations

function parse_resword(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    next(ps)
    decl = parse_expression
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    ps.ws_delim = true
    bits = parse_expression(ps)
    ps.ws_delim = false
    decl = parse_expression(ps)
    return BITSTYPE(bits, decl)
end



function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    ps.ws_delim = true
    decl = parse_expression(ps)
    ps.ws_delim = false
    def = parse_expression(ps)
    return TYPEALIAS(decl, def)
end


function parse_resword(ps::ParseState, ::Type{Val{Tokens.CONST}})
    start = ps.t.startbyte
    decl = parse_expression(ps)
    return CONST(ps.t.endbyte-start, decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.GLOBAL}})
    start = ps.t.startbyte
    decl = parse_expression(ps)
    return GLOBAL(ps.t.endbyte-start, decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.LOCAL}})
    start = ps.t.startbyte
    decl = parse_expression(ps)
    return LOCAL(ps.t.endbyte-start, decl)
end

function parse_resword(ps::ParseState, ::Type{Val{Tokens.RETURN}}) 
    start = ps.t.startbyte
    decl = parse_expression(ps)
    return RETURN(ps.t.endbyte-start, decl)
end

# function parse_resword(ps::ParseState, ::Type{Val{Tokens.MODULE}})
#     start = ps.t.startbyte
#     name = parse_expression(ps, ps->true)
#     body = parse_resword(ps, Val{Tokens.BEGIN})
#     return MODULE(ps.t.endbyte-start, false, name, body)
# end

# function parse_resword(ps::ParseState, ::Type{Val{Tokens.BAREMODULE}})
#     start = ps.t.startbyte
#     name = parse_expression(ps, ps->true)
#     body = parse_resword(ps, Val{Tokens.BEGIN})
#     return MODULE(ps.t.endbyte-start, true, name, body)
# end

# function parse_resword(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}})
#     start = ps.t.startbyte
#     name = parse_expression(ps)
#     fields = parse_resword(ps, Val{Tokens.BEGIN})
#     return IMMUTABLE(ps.t.endbyte-start, name, fields)
# end

# function parse_resword(ps::ParseState, ::Type{Val{Tokens.TYPE}})
#     start = ps.t.startbyte
#     name = parse_expression(ps)
#     fields = parse_resword(ps, Val{Tokens.BEGIN})
#     return TYPE(ps.t.endbyte-start, name, fields)
# end


# Expr(x::TYPEALIAS) = Expr(:typealias, Expr(x.name), Expr(x.body))
# Expr(x::BITSTYPE) = Expr(:bitstype, Expr(x.bits), Expr(x.name))
# Expr(x::TYPE) = Expr(:type, true, Expr(x.name), Expr(x.fields))
# Expr(x::IMMUTABLE) = Expr(:type, false, Expr(x.name), Expr(x.fields))

# Expr(x::CONST) = Expr(:const, Expr(x.decl))
# Expr(x::GLOBAL) = Expr(:global, Expr(x.decl))
# Expr(x::LOCAL) = Expr(:local, Expr(x.decl))
# Expr(x::RETURN) = Expr(:return, Expr(x.decl))

# Expr(x::MODULE) = Expr(:module, true, Expr(x.name), Expr(x.body))
# Expr(x::BAREMODULE) = Expr(:module, false, Expr(x.name), Expr(x.body))