function Base.show(io::IO, x::INSTANCE,indent=0, pos=0)
    println(io, "⊢","-"^indent, x.val, " : ", pos)
end
function Base.show(io::IO, x::CALL,indent=0, pos=0)
    println(io, "⊢","-"^indent,"call", " : ", pos)
end

function Base.show(io::IO, x::KEYWORD_BLOCK{0},indent=0, pos=0)
    println(io, "⊢","-"^indent, x.opener.val, " : ", pos)
end

function Base.show(io::IO, x::KEYWORD_BLOCK,indent=0, pos=0)
    println(io, "⊢","-"^indent, x.opener.val, " : ", pos)
end

function Base.show(io::IO, x::BLOCK,indent=0, pos=0)
    cnt = 0
    for a in x.args[1:end]
        show(io, a, indent, pos)
        cnt+=a.span
    end   
end

function Base.show(io::IO, x::KEYWORD_BLOCK{3},indent=0, pos=0)
    println(io, "⊢","-"^indent, x.opener.val, " : ", pos)
    cnt = 0
    for a in x.args[2:end]
        show(io, a, indent+1, cnt)
        cnt+=a.span
    end 
end

