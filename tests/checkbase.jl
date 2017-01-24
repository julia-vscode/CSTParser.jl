using Tokenize
after = []
io = open(joinpath(dir, file))
while !eof(io)
    c = read(io, Char)
    if c=='{'
        c = read(io, Char)
        push!(after, c)
    end
end
        
after = []
before = []
io = open(joinpath(dir, file))
while !eof(io)
    c = read(io, Char)
    if c=='{'
        c = read(io, Char)
        push!(after, c)
    elseif read(io, Char)=='{'
        push!(before, c)
    end
end
sort!(unique(after))
sort!(unique(before))