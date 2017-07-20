using CSTParser
using Base.Test

import CSTParser: parse, remlineinfo!, check_base, span

include("diagnostics.jl")
include("parser.jl")
check_base()