using Parser
for n in names(Parser, true, true)
    eval(:(import Parser.$n))
end

function reparse(str, x::EXPR, dirty)
    @assert first(dirty) ≤ last(dirty)
    i0, p0, ind0 = find(x, first(dirty))
    i1, p1, ind1 = find(x, last(dirty))
    if i0 == i1 && i0 isa INSTANCE
        ps = ParseState(str)
        while ps.nt.startbyte < i0.offset
            next(ps)
        end
        new_instance = INSTANCE(next(ps))
        dspan = new_instance.span-i0.span
        p0[end][ind0[end]] = new_instance
        for p in p0
            p.span += dspan
        end     
    end
end


str0 = readstring("jsonrpc.jl")
io0 = IOBuffer(str0)
ps = ParseState(str0)
x = Parser.parse_expression(ps)

dirty = 1687:1687
str = string(str0[1:first(dirty)-1], "aaa", str0[last(dirty)+1:end])
io = IOBuffer(str)


reparse(str, x, dirty)

Expr(io, x)
test_span(x)