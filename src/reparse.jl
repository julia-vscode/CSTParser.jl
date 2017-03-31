using Parser
for n in names(Parser, true, true)
    eval(:(import Parser.$n))
end


function dirty_blocks(x::EXPR, dirty)
    @assert first(dirty) ≤ last(dirty)
    i0, p0, ind0 = find(x, first(dirty))
    i1, p1, ind1 = find(x, last(dirty))
end

function dirtyall()
    T = []
    for i = 1:length(str)
        for j = i+1:length(str)
            t = @elapsed dirty_blocks(x,i:j)
            push!(T, t)
        end
    end
    T
end


"""
    reparse(f::File, newstr, dirty)

Reparses `File` `f` where `newstr` is the edited source file and `dirty`
is the region (byte position range) of the previous version of the source file 
that has changed.
"""
function reparse(f::File, newstr, dirty)
    # find old token
    oldtok, tree, ind = find(f.ast, startbyte)
    success = false
    if oldtok isa IDENTIFIER
        ps = ParseState(newstr)
        # skip to token before start of edit
        while ps.nnt.startbyte < startbyte && !ps.done
            next(ps)
        end
        if ps.nt.kind != Tokens.ENDMARKER
            newtok = INSTANCE(next(ps))
            if newtok isa IDENTIFIER && (oldtok.span - newtok.span) == (endbyte - startbyte - sizeof(newtext))
                tree[end][ind[end]] = newtok
                dspan = newtok.span - oldtok.span
                for e in tree
                    e.span += dspan
                end
                success = true
            end
        end
    end

    # fallback method, parse whole new string
    # if !success
    #     f.ast = parse(newstr, true)
    #     success = true
    # end
    
    # f.includes = (f->joinpath(dirname(path), f)).(_get_includes(f.ast))
    return success
end





str = """
function parse_directory(path::String, proj = Project(path,[]))
    for f in readdir(path)
        if isfile(joinpath(path, f)) && endswith(f, ".jl")
            try
                x = parse(readstring(joinpath(path, f)), true)
                push!(proj.files, File([], (f->joinpath(dirname(path), f)).(_get_includes(x)), joinpath(path, f), x))
            catch
                println("f")
            end
        elseif isdir(joinpath(path, f))
            parse_directory(joinpath(path, f), proj)
        end
    end
    proj
end
"""

newstr = """
function parse_directory(path::String, proj = Project(path,[]))
    for f in readdir(path)
        if isfile(joinpath(path, f)) && endswith(f, ".jl")
            try
                x = parse(readstring(joinpath(path, f)), true)
                push!(proj.files, File([], (f->joinpath(dirname(path), f)).(_get_includes(x)), joinpath(path, f), x))
            catch
                println("f")
            end
        elseif isdir(joinpath(path, f))
            newfunc(joinpath(path, f), proj)
        end
    end
    proj
end
"""

str = "symbol + other"
newstr = "symbol  + other"
f = File([],[],"",parse(str,true))

newtext = " "
startbyte = 7
endbyte = 7
str[startbyte:endbyte]

reparse(f, newstr, startbyte, endbyte, newtext)
Expr(f.ast)