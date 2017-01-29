str = readstring("/home/zac/github/Tokenize/src/token_kinds.jl")
lines = strip.(split(str, '\n'))
filter!(l-> !startswith(l,"begin"), lines)
filter!(l-> !startswith(l,"end"), lines)
filter!(l-> !startswith(l,"'"), lines)
filter!(l-> !startswith(l,")"), lines)
filter!(l-> !startswith(l,"@"), lines)
filter!(l-> !startswith(l,"#"), lines)
filter!(l-> !startswith(l,"const"), lines)
filter!(l-> l!="", lines)

const nametosym = Dict{String,String}()
const symtoname = Dict{String,String}()

for op in split.(lines,',')[33:end]
    n= op[1]
    s = strip(op[2])
    s = strip(s, '#')
    s = strip(s)
    nametosym[n] = s
    symtoname[s] = n
end