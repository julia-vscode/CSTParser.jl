span(t::Tokens.Token) = t.endbyte-t.startbyte
span(x::Expression) = x.span

spanws(x::INSTANCE) = span(x)+length(x.ws)
blockstart(x::KEYWORD_BLOCK) = spanws(x.opener)