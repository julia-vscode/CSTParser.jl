span(t::Tokens.Token) = t.endbyte-t.startbyte
span(x::Expression) = x.span

spanws(x::INSTANCE) = span(x)+length(closer(x).ws)
spanws(x::KEYWORD_BLOCK) = span(x)+length(closer(x).ws)
blockstart(x::KEYWORD_BLOCK) = spanws(x.opener)

closer(x::KEYWORD_BLOCK{3}) = x.closer
closer(x::Union{INSTANCE,OPERATOR}) = x
