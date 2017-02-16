function closer(ps::ParseState)
    (ps.closer.newline && ps.ws.kind == Tokens.begin_literal) ||
    (ps.nt.kind == Tokens.SEMICOLON) ||
    (isoperator(ps.nt) && precedence(ps.nt)<=ps.closer.precedence) ||
    (ps.nt.kind == Tokens.LPAREN && ps.closer.precedence>14) ||
    (ps.nt.kind == Tokens.LBRACE && ps.closer.precedence>14) ||
    (ps.nt.kind == Tokens.LSQUARE && ps.closer.precedence>14) ||
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


"""
    @closer ps rule body 

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


function declares_function(x::Expression)
    if x isa EXPR
        if x.head isa INSTANCE{KEYWORD,Tokens.FUNCTION}
            return true
        elseif x.head isa INSTANCE{OPERATOR{1}, Tokens.EQ} && x.args[1] isa EXPR && x.args[1].head==CALL
            return true
        else
            return false
        end
    else
        return false
    end
end

get_id{K}(x::INSTANCE{IDENTIFIER,K}) = x

function get_id(x::EXPR)
    if x.head isa INSTANCE{OPERATOR{6}, Tokens.ISSUBTYPE} || x.head isa INSTANCE{OPERATOR{14}, Tokens.DECLARATION}
        return get_id(x.args[1])
    elseif x.head == CURLY
        return get_id(x.args[1])
    else
        return x
    end
end

get_t{K}(x::INSTANCE{IDENTIFIER,K}) = :Any

function get_t(x::EXPR)
    if x.head isa INSTANCE{OPERATOR{14}, Tokens.DECLARATION}
        return x.args[2]
    else
        return :Any
    end
end