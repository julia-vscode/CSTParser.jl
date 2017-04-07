dep = parse(readstring(Base.functionloc(Base.depwarn)[1]), true)

for x in dep
    if x isa EXPR && x.head == MACROCALL && x.args[1] isa IDENTIFIER && (x.args[1].val == Symbol("@deprecate") || x.args[1].val == Symbol("@deprecate_binding"))
        old = x.args[2]
        replacement = x.args[3]
        if old isa IDENTIFIER && replacement isa IDENTIFIER
            deprecated_symbols[old.val] = replacement.val
            # push!(deprecated_symbols, old.val)
        elseif x isa EXPR && x.head == CALL
            try 
                deprecated_symbols[_get_fname(old).val] = _get_fname(replacement).val
            end
        end
    # elseif x isa EXPR && x.head isa KEYWORD{Tokens.FOR}
    #     v = x[2][1].val
    #     list = Expr.(x[2][3])
    end
end

# function is_codegen_loop(x)
#     if x isa EXPR && x.head isa KEYWORD{Tokens.FOR} && ((x[2].head == CALL && x[2].args[1] isa OPERATOR{6, Tokens.IN}) || (x[2].head isa OPERATOR{1,Tokens.EQ}) && )

#     end
#     false
# end