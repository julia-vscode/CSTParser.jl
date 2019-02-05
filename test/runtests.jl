using CSTParser
using Test

import CSTParser: parse, remlineinfo!, span, flisp_parse

@testset "CSTParser" begin

include("parser.jl")
include("interface.jl")
CSTParser.check_base()

end
