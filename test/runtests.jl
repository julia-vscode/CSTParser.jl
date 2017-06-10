using CSTParser
using Base.Test

import CSTParser: parse, remlineinfo!, check_base, span
# write your own tests here
# include("parser.jl")
# check_base()

ps = ParseState("""
abstract T
type T end
immutable T end
typealias T T
bitstype T 8""")
x,ps = CSTParser.parse(ps, true)
@test ps.diagnostics[1].loc == 0:8
@test ps.diagnostics[2].loc == 11:15
@test ps.diagnostics[3].loc == 22:31
@test ps.diagnostics[4].loc == 38:47
@test ps.diagnostics[5].loc == 52:60
