using Parser
for n in names(Parser, true, true)
    eval(:(import Parser.$n))
end

str, startbyte, endbyte, text = "a + b", 0, 0, "x"
newstr = string(str[1:startbyte], text, str[startbyte+1:end])
f = File([], [], "", Parser.parse(str, true))
reparse(f, newstr, startbyte, endbyte, c.text)

str, startbyte, endbyte, text = "a + b", 1, 1, "x"
newstr = string(str[1:startbyte], text, str[startbyte+1:end])
f = File([], [], "", Parser.parse(str, true))
reparse(f, newstr, startbyte, endbyte, c.text)

str, startbyte, endbyte, text = "a + b", 4, 4, "b"
newstr = string(str[1:startbyte], text, str[startbyte+1:end])
f = File([], [], "", Parser.parse(str, true))
reparse(f, newstr, startbyte, endbyte, text)

str, startbyte, endbyte, text = "a + b", 5, 5, "b"
newstr = string(str[1:startbyte], text, str[startbyte+1:end])
f = File([], [], "", Parser.parse(str, true))
reparse(f, newstr, startbyte, endbyte, text)


function reparse(f::File, newstr, startbyte, endbyte, text)
    size_new = sizeof(newstr)
    size_old = size_new - sizeof(text) + startbyte - endbyte

    if isempty(f.ast.args)
        f.ast = parse(newstr, true)
        return
    elseif startbyte == size_old
        startbyte1 = 0 
        for i in 1:length(f.ast)-1
            startbyte1 += f.ast[i].span
        end
        ps = ParseState(newstr)
        while ps.nt.startbyte < startbyte1 && !ps.done
            next(ps)
        end
        newblocks, ps = parse(ps, true)
        pop!(f.ast.args)
        append!(f.ast.args, newblocks.args)
        f.ast.span = sum(x.span for x in f.ast)
        return 
    end

    # find old token
    first_tok, first_tree, first_ind = find(f.ast, startbyte)
    last_tok, last_tree, last_ind = find(f.ast, endbyte)

    if first_tok == last_tok && first_tok isa LITERAL || first_tok isa IDENTIFIER
        ps = ParseState(newstr)
        while ps.nnt.startbyte < startbyte && !ps.done
            next(ps)
        end
        if ps.nt.kind == Tokens.COMMENT
            new_tok, ps = parse(ps)
        elseif ps.nt.kind == Tokens.IDENTIFIER
            new_tok = INSTANCE(next(ps))
        else
            return
        end

        insert_range = endbyte - startbyte
        if new_tok.span == first_tok.span + sizeof(text) - insert_range
            first_tree[end][first_ind[end]] = new_tok
            Dspan = new_tok.span - first_tok.span
            for x in first_tree
                x.span += 1
            end
        end
    end
    
    if Expr(parse(newstr, true)) != Expr(f.ast)
        info("reparse failed")
        info(Expr(parse(newstr, true)))
        info(Expr(f.ast))
        f.ast = parse(newstr, true)
    end
end



function get_byteposition(doc, line, character)
    line_offsets = get_line_offsets(doc)

    current_offset = line == 0 ? 0 : line_offsets[line]
    for i=1:character
        current_offset = nextind(doc._content, current_offset)
    end
    return current_offset
end


