function closer(ps::ParseState)
    (ps.closer.newline && ps.ws.kind == NewLineWS) ||
    (ps.closer.semicolon && ps.ws.kind == SemiColonWS) ||
    (isoperator(ps.nt) && precedence(ps.nt)<=ps.closer.precedence) ||
    (ps.nt.kind == Tokens.LPAREN && ps.closer.precedence>14) ||
    (ps.nt.kind == Tokens.LBRACE && ps.closer.precedence>14) ||
    (ps.nt.kind == Tokens.LSQUARE && ps.closer.precedence>14) ||
    (ps.nt.kind == Tokens.COMMA && ps.closer.precedence>0) ||
    (ps.closer.eof && ps.nt.kind==Tokens.ENDMARKER) ||
    (ps.closer.comma && iscomma(ps.nt)) || 
    (ps.closer.tuple && (iscomma(ps.nt) || (!ps.closer.paren && isassignment(ps.nt)))) ||
    (ps.nt.kind==Tokens.FOR && ps.closer.precedence>14) ||
    (ps.closer.paren && ps.nt.kind==Tokens.RPAREN) ||
    (ps.closer.brace && ps.nt.kind==Tokens.RBRACE) ||
    (ps.closer.square && ps.nt.kind==Tokens.RSQUARE) ||
    (ps.closer.block && ps.nt.kind==Tokens.END) ||
    (ps.closer.ifelse && ps.nt.kind==Tokens.ELSEIF || ps.nt.kind==Tokens.ELSE) ||
    (ps.closer.ifop && isoperator(ps.nt) && (precedence(ps.nt)<=1 || ps.nt.kind==Tokens.COLON)) ||
    (ps.closer.trycatch && (ps.nt.kind==Tokens.CATCH || ps.nt.kind==Tokens.FINALLY || ps.nt.kind==Tokens.END)) ||
    (ps.closer.ws && (!isempty(ps.ws) && !((isoperator(ps.nt)) || ps.nt.kind == Tokens.COMMA || ps.t.kind == Tokens.COMMA|| ps.nt.kind == Tokens.FOR || ps.nt.kind == Tokens.DO)))
end

"""
    @closer ps rule body 

Continues parsing closing on `rule`.
"""
macro closer(ps, opt, body)
    quote
        local tmp1 = $(esc(ps)).closer.$opt
        $(esc(ps)).closer.$opt = true
        out = $(esc(body))
        $(esc(ps)).closer.$opt = tmp1
        out
    end
end

"""
    @nocloser ps rule body 

Continues parsing not closing on `rule`.
"""
macro nocloser(ps, opt, body)
    quote
        local tmp1 = $(esc(ps)).closer.$opt
        $(esc(ps)).closer.$opt = false
        out = $(esc(body))
        $(esc(ps)).closer.$opt = tmp1
        out
    end
end

"""
    @precedence ps prec body 

Continues parsing binary operators until it hits a more loosely binding
operator (with precdence lower than `prec`).
"""
macro precedence(ps, prec, body)
    quote
        local tmp1 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.precedence = $(esc(prec))
        out = $(esc(body))
        $(esc(ps)).closer.precedence = tmp1
        out
    end
end

"""
    @default ps body

Parses the next expression using default closure rules.
"""
macro default(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.newline
        local tmp2 = $(esc(ps)).closer.semicolon
        local tmp3 = $(esc(ps)).closer.eof
        local tmp4 = $(esc(ps)).closer.tuple
        local tmp5 = $(esc(ps)).closer.comma
        # local tmp6 = $(esc(ps)).closer.paren
        # local tmp7 = $(esc(ps)).closer.brace
        # local tmp8 = $(esc(ps)).closer.square
        local tmp9 = $(esc(ps)).closer.block
        local tmp10 = $(esc(ps)).closer.ifelse
        local tmp11 = $(esc(ps)).closer.ifop
        local tmp12 = $(esc(ps)).closer.trycatch
        local tmp13 = $(esc(ps)).closer.ws
        local tmp14 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.newline = true
        $(esc(ps)).closer.semicolon = true
        $(esc(ps)).closer.eof = true
        $(esc(ps)).closer.tuple = false
        $(esc(ps)).closer.comma = false
        # $(esc(ps)).closer.paren = false
        # $(esc(ps)).closer.brace = false
        # $(esc(ps)).closer.square = false
        # $(esc(ps)).closer.block = false
        $(esc(ps)).closer.ifelse = false
        $(esc(ps)).closer.ifop = false
        $(esc(ps)).closer.trycatch = false
        $(esc(ps)).closer.ws = false
        $(esc(ps)).closer.precedence = -1

        out = $(esc(body))
        
        $(esc(ps)).closer.newline = tmp1
        $(esc(ps)).closer.semicolon = tmp2
        $(esc(ps)).closer.eof = tmp3
        $(esc(ps)).closer.tuple = tmp4
        $(esc(ps)).closer.comma = tmp5
        # $(esc(ps)).closer.paren = tmp6
        # $(esc(ps)).closer.brace = tmp7
        # $(esc(ps)).closer.square = tmp8
        $(esc(ps)).closer.block = tmp9
        $(esc(ps)).closer.ifelse = tmp10
        $(esc(ps)).closer.ifop = tmp11
        $(esc(ps)).closer.trycatch = tmp12
        $(esc(ps)).closer.ws = tmp13
        $(esc(ps)).closer.precedence = tmp14
        out
    end
end

"""
    @clear ps body

Parses the next expression using default closure rules.
"""
macro clear(ps, body)
    quote
        local tmp1 = $(esc(ps)).closer.newline
        local tmp2 = $(esc(ps)).closer.semicolon
        local tmp3 = $(esc(ps)).closer.eof
        local tmp4 = $(esc(ps)).closer.tuple
        local tmp5 = $(esc(ps)).closer.comma
        # local tmp6 = $(esc(ps)).closer.paren
        # local tmp7 = $(esc(ps)).closer.brace
        # local tmp8 = $(esc(ps)).closer.square
        local tmp9 = $(esc(ps)).closer.block
        local tmp10 = $(esc(ps)).closer.ifelse
        local tmp11 = $(esc(ps)).closer.ifop
        local tmp12 = $(esc(ps)).closer.trycatch
        local tmp13 = $(esc(ps)).closer.ws
        local tmp14 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.newline = false
        $(esc(ps)).closer.semicolon = false
        $(esc(ps)).closer.eof = false
        $(esc(ps)).closer.tuple = false
        $(esc(ps)).closer.comma = false
        # $(esc(ps)).closer.paren = false
        # $(esc(ps)).closer.brace = false
        # $(esc(ps)).closer.square = false
        $(esc(ps)).closer.block = false
        $(esc(ps)).closer.ifelse = false
        $(esc(ps)).closer.ifop = false
        $(esc(ps)).closer.trycatch = false
        $(esc(ps)).closer.ws = false
        $(esc(ps)).closer.precedence = 0

        out = $(esc(body))
        
        $(esc(ps)).closer.newline = tmp1
        $(esc(ps)).closer.semicolon = tmp2
        $(esc(ps)).closer.eof = tmp3
        $(esc(ps)).closer.tuple = tmp4
        $(esc(ps)).closer.comma = tmp5
        # $(esc(ps)).closer.paren = tmp6
        # $(esc(ps)).closer.brace = tmp7
        # $(esc(ps)).closer.square = tmp8
        $(esc(ps)).closer.block = tmp9
        $(esc(ps)).closer.ifelse = tmp10
        $(esc(ps)).closer.ifop = tmp11
        $(esc(ps)).closer.trycatch = tmp12
        $(esc(ps)).closer.ws = tmp13
        $(esc(ps)).closer.precedence = tmp14
        out
    end
end

"""
    @scope ps scope body 

Continues parsing closing on `rule`.
"""
macro scope(ps, new_scope, body)
    quote
        local tmp1 = $(esc(ps)).current_scope
        $(esc(ps)).current_scope = $(esc(new_scope))
        out = $(esc(body))
        $(esc(ps)).current_scope = tmp1
        out
    end
end

"""
    @noscope ps body

Continues parsing not tracking declared variables.
"""
macro noscope(ps, body)
    quote
        local tmp1 = $(esc(ps)).trackscope
        $(esc(ps)).trackscope = false
        out = $(esc(body))
        $(esc(ps)).trackscope = tmp1
        out
    end
end

isidentifier(t::Token) = t.kind == Tokens.IDENTIFIER

isliteral(t::Token) = Tokens.begin_literal < t.kind < Tokens.end_literal

isbool(t::Token) =  Tokens.TRUE ≤ t.kind ≤ Tokens.FALSE
iscomma(t::Token) =  t.kind == Tokens.COMMA

iskw(t::Token) = Tokens.iskeyword(t.kind)

isinstance(t::Token) = isidentifier(t) ||
                       isliteral(t) ||
                       isbool(t) || 
                       iskw(t)


ispunctuation(t::Token) = t.kind == Tokens.COMMA ||
                          t.kind == Tokens.END ||
                          Tokens.LSQUARE ≤ t.kind ≤ Tokens.RPAREN




# Testing functions
function remlineinfo!(x)
    if isa(x,Expr)
        id = find(map(x->isa(x,Expr) && x.head==:line,x.args))
        deleteat!(x.args,id)
        for j in x.args
            remlineinfo!(j)
        end
    end
    x
end



function test_order(x, out = [])
    if x isa EXPR
        for y in x
            test_order(y, out)
        end
    else
        push!(out, x)
    end
    out
end

function test_find(str)
    x = Parser.parse(str)
    for i = 1:sizeof(str)
        find(x, i)
    end
end




function check_file(f::String)
    str = readstring(f)
    ps = ParseState(str)
    io = IOBuffer(str)
    if ps.nt.kind == Tokens.COMMENT
        next(ps)
    end
    ismod = false
    if ps.nt.kind == Tokens.MODULE
        next(ps)
        next(ps)
        ismod = true
    end
    seek(io, ps.nt.startbyte)
    cnt = 0
    failed = []
    while !eof(io)
        if ps.nt.endbyte == length(str)-1
            break
        end
        cnt+=1
        x,ps = try
            Parser.parse(ps)
        end
        if x isa LITERAL{Tokens.TRIPLE_STRING}
            doc = x
            x,ps = Parser.parse(ps)
            x = EXPR(MACROCALL, [GlobalRefDOC, doc, x], doc.span + x.span)
        end
        x0 = Expr(x)
        y = try Base.parse(io) end
        y0 = remlineinfo!(y)
        eq = (x0 == y0)
        
        if !eq
            push!(failed, (x0, y0))
        end
    end
    failed, cnt
end


compare(x,y) = x == y ? true : (x,y)

function compare(x::Expr,y::Expr)
    if x == y
        return true
    else
        if x.head != y.head
            return (x, y)
        end
        if length(x.args) != length(y.args)
            return (x.args, y.args)
        end
        for i = 1:length(x.args)
            t = compare(x.args[i], y.args[i])
            if t!=true
                return t
            end
        end
    end
end

