function Base.show(io::IO, x::INSTANCE,indent=0)
    println(io, " "^indent, " $(x.val)","    [",x.loc.stop-x.loc.start,"]")
end

function Base.show(io::IO, x::QUOTENODE,indent=0)
    println(io, " "^indent, " $(x.val)")
end

function Base.show(io::IO, x::EXPR,indent=0)
    if x.head==CALL
        if x.args[1] isa INSTANCE
            name = string(x.args[1].val)
        else
            name = string(x.args[1].args[1].val)
        end
    else
        name = string(x.head.val)
    end
    println(io, " "^indent, "↘ ", name,"    [",x.loc.stop-x.loc.start,"]")
    for a in x.args[(1+(x.head==CALL)):end]
        show(io, a, indent+1)
    end 
end

