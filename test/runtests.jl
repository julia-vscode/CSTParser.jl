using CSTParser
using Test

import CSTParser: parse, remlineinfo!, span, flisp_parse, typof, kindof, valof

@testset "CSTParser" begin

    include("parser.jl")
    include("interface.jl")
    include("display.jl")
    CSTParser.check_base()

end
