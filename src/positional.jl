"""
    span(x)

Returns the number of bytes between the first and last character of 
the expression.
"""
function span end
"""
    span(x)

Returns the number of bytes between the first character of the 
expression and the last character of any trailing whitespace.
"""
function spanws end
"""
    opener(x)

Returns the expression that starts x.
"""
function opener end
"""
    opener(x)

Returns the expression that closes x.
"""
function closer end

span(t::Tokens.Token) = t.endbyte-t.startbyte



span(x::COMPARISON) = sum(spanws(a) for a in x.args)-length(x.args[end].ws)

blockstart(x::KEYWORD_BLOCK) = spanws(x.opener)

# INSTANCE
opener(x::Union{INSTANCE}) = x
closer(x::Union{INSTANCE}) = x
span(x::INSTANCE) = x.span
spanws(x::INSTANCE) = span(x)+length(closer(x).ws)


# CALL
opener(x::CALL) = opener(x.name)
closer(x::CALL) = closer(last(x.args))
span(x::CALL) = span(x.name) + 
                sum(spanws(a) for a in x.args) + 
                length(x.args)-1 + 
                2


# KEYWORD_BLOCK{3}
opener(x::KEYWORD_BLOCK{3}) = x.opener
closer(x::KEYWORD_BLOCK{3}) = x.closer
span(x::KEYWORD_BLOCK) = x.span
spanws(x::KEYWORD_BLOCK) = span(x)+length(closer(x).ws)



