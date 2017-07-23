using CSTParser
using Base.Test

import CSTParser: parse, remlineinfo!, span, flisp_parse

include("diagnostics.jl")
include("parser.jl")
CSTParser.check_base()