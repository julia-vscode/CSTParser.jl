span(t::Tokens.Token) = t.endbyte-t.startbyte




span(x::COMPARISON) = sum(spanws(a) for a in x.args)-length(x.args[end].ws)

blockstart(x::KEYWORD_BLOCK) = spanws(x.opener)


opener(x::KEYWORD_BLOCK{3}) = x.opener
closer(x::KEYWORD_BLOCK{3}) = x.closer
span(x::KEYWORD_BLOCK) = x.span
spanws(x::KEYWORD_BLOCK) = span(x)+length(closer(x).ws)

opener(x::Union{INSTANCE}) = x
closer(x::Union{INSTANCE}) = x
span(x::INSTANCE) = x.span
spanws(x::INSTANCE) = span(x)+length(closer(x).ws)

