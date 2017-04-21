using CSTParser
using Base.Test

import CSTParser: parse, remlineinfo!, check_base, span
# write your own tests here
include("parser.jl")
check_base()