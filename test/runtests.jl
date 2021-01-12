using CSTParser, Test, CSTParser.Tokenize
using CSTParser: parse, remlineinfo!, span, headof, kindof, valof

@testset "CSTParser" begin
    include("spec.jl")
    include("parser.jl")
    include("interface.jl")
    include("display.jl")
    include("iterate.jl")
    CSTParser.check_base()
    include("errparse.jl")

end
