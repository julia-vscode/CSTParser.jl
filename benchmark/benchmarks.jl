using CSTParser, BenchmarkTools

bs = [
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("const x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("return x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("return"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("abstract type T end"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("primitive type T I end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("primitive"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("import x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("import x, x, x, x, x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("import x.x.x.x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("import x:x, x.x"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("export x"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("export x, x, x, x, x, x"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("begin end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("quote end"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("function end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("function f end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("function f() end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("function f() where T where T end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("for i = I end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("for i = I, j = J, k = K end"))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("while cond end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("if cond end"))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""if cond
else
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""if cond
elseif cond
elseif cond
elseif cond
elseif cond
elseif cond
else
end"""))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""let x = 1
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""let x = 1, y = 2, z = 3
end"""))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""try
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""try
catch
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""try
catch e
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""try
catch e
finally
end"""))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState(""" f() do x
end"""))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""struct
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""mutable struct
end"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""module x
end"""))

@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""x=x=x=x=x"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""x=>x=>x=>x=>x"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""x ? x : x ? x : x ? x : x"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""x||x||x||x||x"""))
@benchmarkable CSTParser.parse_expression(ps) setup = (ps = ParseState("""x.x.x.x.x"""))
]
