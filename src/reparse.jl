using Parser
for n in names(CSTParser, true, true)
    eval(:(import CSTParser.$n))
end

applychange(str, s1, s2, t) = string(str[1:s1], t, str[s2 + 1:end])

str, s1, s2, txt = "a + b", 0, 0, "x"
str, s1, s2, txt = "a + b", 1, 1, "x"
str, s1, s2, txt = "a + b", 2, 2, "x"
str, s1, s2, txt = "a + b", 4, 4, "b"
str, s1, s2, txt = "a + b", 5, 5, "b"
str, s1, s2, txt = "a + b", 4, 5, "c"
str, s1, s2, txt = "function fname(arg) end", 9, 10, "g"
str, s1, s2, txt = "function fname(arg) end", 15, 18, "g"
str, s1, s2, txt = """
function fname(arg)
    if cond == true
        for i = 1:20
            out += arg
        end
    end
end""", 73, 76, "d"
str, s1, s2, txt = "name", 2, 2, "+"

str1 = applychange(str, s1, s2, txt);
f = File([], [], "", Parser.parse(str, true));
reparse(f, str1, s1, s2, txt);


function reparse(f::File, newstr, startbyte, endbyte, text)
    size_new = sizeof(newstr)
    size_old = size_new - sizeof(text) - startbyte + endbyte

    if isempty(f.ast.args)
        f.ast = parse(newstr, true)
        return
    # elseif startbyte == size_old
    #     startbyte1 = 0 
    #     for i in 1:length(f.ast)-1
    #         startbyte1 += f.ast[i].span
    #     end
    #     ps = ParseState(newstr)
    #     while ps.nt.startbyte < startbyte1 && !ps.done
    #         next(ps)
    #     end
    #     newblocks, ps = parse(ps, true)
    #     pop!(f.ast.args)
    #     append!(f.ast.args, newblocks.args)
    #     f.ast.span = sum(x.span for x in f.ast)
    #     return 
    end

    # find old token
    # if on the last byte of a node we need to check the boundary
    first_tok, first_tree, first_ind = find(f.ast, startbyte)
    if !(first_tok isa IDENTIFIER)
        first_tok, first_tree, first_ind = find(f.ast, startbyte + 1)
    end
    last_tok, last_tree, last_ind = find(f.ast, endbyte)
    if !(last_tok isa IDENTIFIER)
        last_tok, last_tree, last_ind = find(f.ast, endbyte + 1)
    end
    
    

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
        # f.ast = parse(newstr, true)
    end
end



function get_byteposition(doc, line, character)
    line_offsets = get_line_offsets(doc)

    current_offset = line == 0 ? 0 : line_offsets[line]
    for i = 1:character
        current_offset = nextind(doc._content, current_offset)
    end
    return current_offset
end


