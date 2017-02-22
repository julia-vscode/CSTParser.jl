using Parser
for n in names(Parser, true, true)
    eval(:(import Parser.$n))
end


function dirty_blocks(x::EXPR, dirty)
    @assert first(dirty) ≤ last(dirty)
    i0, p0, ind0 = find(x, first(dirty))
    i1, p1, ind1 = find(x, last(dirty))
end

function reparse(str, x::EXPR, dirty, n)
    @assert first(dirty) ≤ last(dirty)
    i0, p0, ind0 = find(x, first(dirty))
    i1, p1, ind1 = find(x, last(dirty))
    if i0 == i1 && i0 isa INSTANCE
        ps = ParseState(str)
        while ps.nt.startbyte < i0.offset
            next(ps)
        end
        new_instance = INSTANCE(next(ps))
        if (n-length(dirty))==(i0.span-new_instance.span)
            dspan = new_instance.span-i0.span
            p0[end][ind0[end]] = new_instance
            for p in p0
                p.span += dspan
            end
        end
    end
end




str = """
function fname(arg1,arg2::Int)
    f(x) = safdsdfs(sfd)
    out = 0
    while true
        out += arg1*arg2
        x = 1+2-3*b ^ 3 || (x-3&4)
        x = 1+2-3*b ^ 3 || (x-3&4)
        x = 1+2-3*b ^ 3 || (x-3&4)

    end
end"""
io = IOBuffer(str)
ps = ParseState(str)
y = Parser.parse(str)
x = Parser.parse(str)

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
T =  dirtyall()