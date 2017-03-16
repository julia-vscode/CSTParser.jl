function format(ps::ParseState)
    if ps.formatcheck
        if isoperator(ps.t)
            prec = precedence(ps.t)
            if prec == 8 || prec == 13 || prec == 14 || prec == 15
                if ps.lws.kind != EmptyWS
                    push!(ps.hints, Hint{Hints.DeleteWhiteSpace}(ps.lws.startbyte+1:ps.lws.endbyte+1))
                end
                if ps.ws.kind != EmptyWS
                    push!(ps.hints, Hint{Hints.DeleteWhiteSpace}(ps.ws.startbyte+1:ps.ws.endbyte+1))
                end
            elseif ps.t.kind == Tokens.ISSUBTYPE || ps.t.kind == Tokens.DDDOT
            else
                if ps.lws.kind == EmptyWS
                    push!(ps.hints, Hint{Hints.AddWhiteSpace}(ps.t.startbyte))
                end
                if ps.ws.kind == EmptyWS
                    push!(ps.hints, Hint{Hints.AddWhiteSpace}(ps.t.endbyte+1))
                end
            end
        elseif ps.t.kind == Tokens.COMMA
            if ps.lws.kind != EmptyWS
                push!(ps.hints, Hint{Hints.DeleteWhiteSpace}(ps.lws.startbyte+1:ps.lws.endbyte+1))
            end
            if ps.ws.kind == EmptyWS
                push!(ps.hints, Hint{Hints.AddWhiteSpace}(ps.nt.startbyte))
            end
        elseif ps.t.kind == Tokens.LPAREN || ps.t.kind == Tokens.LBRACE || ps.t.kind == Tokens.LSQUARE
            if ps.ws.kind != EmptyWS
                push!(ps.hints, Hint{Hints.DeleteWhiteSpace}(ps.ws.startbyte+1:ps.ws.endbyte+1))
            end
        elseif ps.t.kind == Tokens.RPAREN || ps.t.kind == Tokens.RBRACE || ps.t.kind == Tokens.RSQUARE
            if ps.lws.kind != EmptyWS
                push!(ps.hints, Hint{Hints.DeleteWhiteSpace}(ps.lws.startbyte+1:ps.lws.endbyte+1))
            end
        elseif ps.t.kind == Tokens.ELSE && ps.ws.kind == WS && ps.nt.kind == Tokens.IF
            push!(ps.hints, Hint{Hints.Useelseif}(ps.t.startbyte))
            Useelseif
        end
    end
end