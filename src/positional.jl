"""
    span(x)

Returns the number of bytes between the first and last character of 
the expression.
"""
function span end
"""
    span(x)

Returns the number of bytes between the first character of the 
expression and the last character of any whitespace trailing behind 
the last character of the expression.
"""
function spanws end




import Base: first, last




span(x::Expression) = x.stop-x.start
spanws(x::Expression) = span(x) + length(last(x).ws)
# INSTANCE
first(x::Union{INSTANCE}) = x
last(x::Union{INSTANCE}) = x
whitespace(x::INSTANCE) = x.ws

# CHAIN
first(x::CHAIN) = first(first(x.args))
last(x::CHAIN) = last(last(x.args))
whitespace(x::CHAIN) = whitespace(last(x))

# CALL
first(x::CALL) = first(x.name)
last(x::CALL) = last(last(x.args))


# KEYWORD_BLOCK{3}
first(x::KEYWORD_BLOCK{3}) = x.opener
last(x::KEYWORD_BLOCK{3}) = x.closer





span(x::CURLY) = x.span