@testitem "self test" begin
    include("../shared.jl")

    for (root, dirs, files) in walkdir(joinpath(@__DIR__, "..", ".."))
        for file in files
            if endswith(file, ".jl")
                test_iter_spans(CSTParser.parse(read(joinpath(root, file), String), true))
            end
        end
    end

end
