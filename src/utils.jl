function closer(ps::ParseState)
    (ps.closer.newline && search(ps.ws.val, '\n')!=0) ||
    (isoperator(ps.nt) && precedence(ps.nt)<=ps.closer.precedence) ||
    (ps.closer.eof && ps.nt.kind==Tokens.ENDMARKER) ||
    (ps.closer.tuple && (iscomma(ps.nt) || isassignment(ps.nt))) ||
    (ps.closer.comma && iscomma(ps.nt)) ||
    (ps.closer.paren && ps.nt.kind==Tokens.RPAREN) ||
    (ps.closer.brace && ps.nt.kind==Tokens.RBRACE) ||
    (ps.closer.square && ps.nt.kind==Tokens.RSQUARE) ||
    (ps.closer.block && ps.nt.kind==Tokens.END) ||
    (ps.closer.ifelse && ps.nt.kind==Tokens.ELSEIF || ps.nt.kind==Tokens.ELSE) ||
    (ps.closer.ifop && isoperator(ps.nt) && (precedence(ps.nt)<=1 || ps.nt.kind==Tokens.COLON)) ||
    (ps.closer.trycatch && ps.nt.kind==Tokens.CATCH || ps.nt.kind==Tokens.END) ||
    (ps.closer.ws && (!isempty(ps.ws) && !isoperator(ps.nt)))

end

"""
    @nocloser ps rule body 

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
        local tmp3 = $(esc(ps)).closer.eof
        local tmp4 = $(esc(ps)).closer.tuple
        local tmp5 = $(esc(ps)).closer.comma
        local tmp6 = $(esc(ps)).closer.paren
        local tmp7 = $(esc(ps)).closer.brace
        local tmp8 = $(esc(ps)).closer.square
        local tmp9 = $(esc(ps)).closer.block
        local tmp10 = $(esc(ps)).closer.ifelse
        local tmp11 = $(esc(ps)).closer.ifop
        local tmp12 = $(esc(ps)).closer.trycatch
        local tmp13 = $(esc(ps)).closer.ws
        local tmp14 = $(esc(ps)).closer.precedence
        $(esc(ps)).closer.newline = true
        $(esc(ps)).closer.eof = true
        $(esc(ps)).closer.tuple = false
        $(esc(ps)).closer.comma = false
        $(esc(ps)).closer.paren = false
        $(esc(ps)).closer.brace = false
        $(esc(ps)).closer.square = false
        # $(esc(ps)).closer.block = false
        $(esc(ps)).closer.ifelse = false
        $(esc(ps)).closer.ifop = false
        $(esc(ps)).closer.trycatch = false
        $(esc(ps)).closer.ws = false
        $(esc(ps)).closer.precedence = 0

        out = $(esc(body))
        
        $(esc(ps)).closer.newline = tmp1
        $(esc(ps)).closer.eof = tmp3
        $(esc(ps)).closer.tuple = tmp4
        $(esc(ps)).closer.comma = tmp5
        $(esc(ps)).closer.paren = tmp6
        $(esc(ps)).closer.brace = tmp7
        $(esc(ps)).closer.square = tmp8
        $(esc(ps)).closer.block = tmp9
        $(esc(ps)).closer.ifelse = tmp10
        $(esc(ps)).closer.ifop = tmp11
        $(esc(ps)).closer.trycatch = tmp12
        $(esc(ps)).closer.ws = tmp13
        $(esc(ps)).closer.precedence = tmp14
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

