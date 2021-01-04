function parseall(str)
    pos = firstindex(str)
    expr = Expr(:file)
    while pos <= lastindex(str)
        ex, pos = Meta.parse(str, pos)
        push!(expr.args, ex)
    end
    return expr
end

# CSTParser.parse inserts a nothing at the beginning for comments and Meta.parse does the same at the end
function strip_nothing!(ex)
    if length(ex.args) > 1
        if ex.args[1] === nothing
            popfirst!(ex.args)
        elseif ex.args[end] === nothing
            pop!(ex.args)
        end
    end
end

function test_julia_files(dir, maxcheck = 3000)
    i = 0
    println("Test parsing of source files (not only *.jl) in $dir:")
    for (root, dir, files) in walkdir(dir)
        for file in files
            ext = splitext(file)[2]
            if ext in (".jl", ".md", ".html", ".scm", ".h", ".cpp", ".c")
                if i > maxcheck
                    println()
                    return
                end
                i += 1
                print(".")
                path = joinpath(root, file)
                content = read(path, String)

                ex1, ex2 = nothing, nothing
                try
                    ex1 = strip_nothing!(CSTParser.remlineinfo!(parseall(content)))
                catch err
                    err isa InterruptException && rethrow()
                    if ext == ".jl"
                        println()
                        @warn "Meta.parse errored in $file" exception=err
                    end
                end
                try
                    ex2 = strip_nothing!(Expr(CSTParser.parse(content, true)))
                catch err
                    err isa InterruptException && rethrow()
                    if ext == ".jl"
                        println()
                        @error "CSTParser.parse errored in $file" exception=(err, catch_backtrace())
                    end
                end
                if ex1 !== nothing && ex2 !== nothing
                    @test ex1 == ex2
                end
            end
        end
    end
    println()
end

using Pkg
@testset "CSTParser.parse vs Meta.parse" begin
    test_julia_files(dirname(Sys.BINDIR))
    test_julia_files(dirname(@__DIR__))
    test_julia_files(Pkg.depots1())
end
