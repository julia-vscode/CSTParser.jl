using CSTParser
using Test

import CSTParser: parse, remlineinfo!, span, flisp_parse, headof, kindof, valof
using CSTParser.Tokenize

@testset "CSTParser" begin
    include("spec.jl")
    include("parser.jl")
    include("interface.jl")
    include("display.jl")
    include("iterate.jl")
    CSTParser.check_base()
    include("errparse.jl")

end
