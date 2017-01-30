closer_default(ps::ParseState) = search(ps.ws.val, '\n')!=0 ||
                                 ps.nt.kind == Tokens.SEMICOLON ||
                                 ps.nt.kind == Tokens.ENDMARKER ||
                                 ps.nt.kind == Tokens.RPAREN ||
                                 ps.nt.kind == Tokens.RBRACE ||
                                 ps.nt.kind == Tokens.RSQUARE || 
                                 (ps.ws_delim && !isoperator(ps.t) && isinstance(ps.nt) && length(ps.ws.val)>0)

closer_ws_no_newline(ps::ParseState) = !(Tokens.begin_ops < ps.nt.kind < Tokens.end_ops) &&
                          search(ps.ws.val, '\n')==0

closer_no_ops(p) = ps->closer_default(ps) || (isoperator(ps.nt) && precedence(ps.nt)<=p)




isidentifier(t::Token) = t.kind == Tokens.IDENTIFIER

isliteral(t::Token) = Tokens.begin_literal < t.kind < Tokens.end_literal

isbool(t::Token) =  Tokens.TRUE ≤ t.kind ≤ Tokens.FALSE

iskw(t::Token) = Tokens.iskeyword(t.kind)

isinstance(t::Token) = isidentifier(t) ||
                       isliteral(t) ||
                       isbool(t) || 
                       iskw(t)



