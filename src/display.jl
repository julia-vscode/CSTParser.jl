function Base.show(io::IO, x::INSTANCE,indent=0)
    println(io, " "^indent, " $(x.val)","    [",x.loc.stop-x.loc.start,"]")
end

function Base.show(io::IO, x::QUOTENODE,indent=0)
    println(io, " "^indent, " $(x.val)")
end

function Base.show(io::IO, x::EXPR,indent=0)
    println(io, " "^indent, "↘ ", x.head==CALL ? string(x.args[1].val) : string(x.head.val),"    [",x.loc.stop-x.loc.start,"]")
    for a in x.args[(1+(x.head==CALL)):end]
        show(io, a, indent+1)
    end 
end

