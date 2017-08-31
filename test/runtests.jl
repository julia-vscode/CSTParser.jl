using CSTParser
using Base.Test

import CSTParser: parse, remlineinfo!, span, flisp_parse

include("parser.jl")
include("diagnostics.jl")
CSTParser.check_base()
