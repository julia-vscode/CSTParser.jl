using CSTParser, BenchmarkTools
parse = CSTParser.parse

suite = BenchmarkGroup()

suite["operators"] = BenchmarkGroup()

suite["operators"]["unary"] = BenchmarkGroup()
suite["operators"]["binary"] = BenchmarkGroup()
suite["operators"]["conditional"] = BenchmarkGroup()
    
suite["operators"]["unary"]["generic"] = @benchmarkable parse("::T")
suite["operators"]["unary"]["quote"] = @benchmarkable parse(":T")
suite["operators"]["unary"]["dddots"] = @benchmarkable parse("a...............")
    
suite["operators"]["binary"]["generic ltor"] = @benchmarkable parse("a - b - c - d - e")
suite["operators"]["binary"]["assignment"] = @benchmarkable parse("a = b = c = d = e")
suite["operators"]["binary"]["comparison"] = @benchmarkable parse("a < b")
suite["operators"]["binary"]["comparison syntax call"] = @benchmarkable parse("a <: b")
suite["operators"]["binary"]["comparison chain"] = @benchmarkable parse("a < b < c < d < e")
suite["operators"]["binary"]["colon"] = @benchmarkable parse("a:b:c:d:e:f:g:h:i:j:k")
suite["operators"]["binary"]["plus chain"] = @benchmarkable parse("a + b + c + d + e")
suite["operators"]["binary"]["power"] = @benchmarkable parse("a ^ b ^ c ^ d ^ e")
suite["operators"]["binary"]["dot"] = @benchmarkable parse("a.b.c.d.e")
suite["operators"]["binary"]["dot w/ paren"] = @benchmarkable parse("a.(b).(c).(d).(e)")
suite["operators"]["binary"]["dot w/ res word"] = @benchmarkable parse("a.in.isa.where.function")
suite["operators"]["binary"]["dot w/ colon"] = @benchmarkable parse("a.:+.:-.:*.:/")
suite["operators"]["binary"]["anon func"] = @benchmarkable parse("a -> b -> c -> d -> e")

suite["operators"]["conditional"]["generic"] = @benchmarkable parse("a ? b : c")
suite["operators"]["conditional"]["repeated"] = @benchmarkable parse("a ? b : c ? d : e ? f : g ? h : i ? j : k")


suite["tuples"] = BenchmarkGroup()
suite["tuples"]["generic"] = @benchmarkable parse("a, b, c, d, e")
suite["tuples"]["assignment"] = @benchmarkable parse("a, = b, = c, = d, = e")


suite["functions"] = BenchmarkGroup()
suite["functions"]["no call"] = @benchmarkable parse("function func end")
suite["functions"]["no args"] = @benchmarkable parse("function func() end")
suite["functions"]["w/ args"] = @benchmarkable parse("function func(arg, arg, arg, arg, arg) end")
suite["functions"]["w/ kw args"] = @benchmarkable parse("function func(arg = 1, arg = 1, arg = 1, arg = 1, arg = 1) end")
suite["functions"]["w/ parameters"] = @benchmarkable parse("function func(;arg = 1, arg = 1, arg = 1, arg = 1, arg = 1) end")
suite["functions"]["w/ where"] = @benchmarkable parse("function func(arg::T) where T where T where T where T where T end")


suite["loops"] = BenchmarkGroup()
suite["loops"]["while"] = @benchmarkable parse("while true end")
suite["loops"]["for"] = @benchmarkable parse("for iter in I end")
suite["loops"]["for (x5)"] = @benchmarkable parse("for iter in I, iter in I, iter in I, iter in I, iter in I end")
suite["loops"]["generator"] = @benchmarkable parse("iter for iter in I")
suite["loops"]["generator (x5)"] = @benchmarkable parse("iter for iter in I, iter in I, iter in I, iter in I, iter in I")


suite["if"] = BenchmarkGroup()
suite["if"]["generic"] = @benchmarkable parse("if cond end")
suite["if"]["w/ else"] = @benchmarkable parse("if cond else end")
suite["if"]["w/ elseif"] = @benchmarkable parse("if cond elseif cond end")
suite["if"]["w/ elseif & else"] = @benchmarkable parse("if cond elseif cond else end")
suite["if"]["long nested"] = @benchmarkable parse("if cond elseif cond elseif cond elseif cond elseif cond elseif cond else end")

suite["imports"] = BenchmarkGroup()
suite["imports"]["1"] = @benchmarkable parse("import a")
suite["imports"]["2"] = @benchmarkable parse("import a, b, c, d, e")
suite["imports"]["3"] = @benchmarkable parse("import a: b, c, d, e")

results = run(suite, verbose = true, seconds = 3)

showall(results)

