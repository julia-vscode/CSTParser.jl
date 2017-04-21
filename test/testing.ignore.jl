using CSTParser
for n in names(CSTParser, true, true)
    eval(:(import CSTParser.$n))
end

# 3869 files


# failed : 0    0.0%
# errored : 2     0.051692943913155855%
# not eq. : 109    2.817265443266994%  -  58     1.4990953734815198%
# base failed : 45    1.1630912380460068%

# failed : 0    0.0%
# errored : 2     0.051692943913155855%
# not eq. : 111    2.86895838718015%
# base failed : 45    1.1630912380460068%







pkgdir = joinpath.("/home/zac/github/pkgdump/v0.6/", readdir("/home/zac/github/pkgdump/v0.6/"))
check_base("/home/zac/github/pkgdump/v0.6/")
errs = check_base()
i=1
i+=1
errs = check_base(joinpath(Pkg.dir(), readdir(Pkg.dir())[i]), true)
[check_base(joinpath(Pkg.dir(), readdir(Pkg.dir())[i]), true) for i in 2:50]
[check_base(joinpath(Pkg.dir(), readdir(Pkg.dir())[i]), true) for i in 100:150]
errs = check_base(Pkg.dir("ColorTypes"), true)
errs = check_base(Pkg.dir(), true)



str = readstring("/home/zac/.julia/v0.6/Distributions/src/multivariate/dirichlet.jl");

xx = parse(str, true);

ps = ParseState(str)
io = IOBuffer(str)

ps.l.io.ptr/ps.l.io.size
x, ps = parse(ps);
x0 = Expr(x);
x1 = remlineinfo!(Base.parse(io));
x0 == x1 && !ps.errored && isempty(span(x)) || (x1 isa Expr && x1.head == :toplevel && x0 == x1.args[1])

while x0 == x1 && !ps.errored && isempty(span(x)) || (x1 isa Expr && x1.head == :toplevel && x0 == x1.args[1])
x, ps = parse(ps);
x0 = Expr(x);
x1 = remlineinfo!(Base.parse(io));
end



ps = ParseState(str)

function f(str)
    x, ps = parse(ParseState(str))
    x0 = Expr(x)
    x1 = remlineinfo!(Base.parse(str))
    !ps.errored && x0 == x1 && isempty(span(x))
end


str = "-(1)a"
str = """!(a = b)"""

ps = ParseState(str);
x, ps = parse(ParseState(str));
x0 = Expr(x)
x1 = remlineinfo!(Base.parse(str))
!ps.errored && x0 == x1 && isempty(span(x))


ps = ParseState(str)
op = INSTANCE(next(ps))
# parse_compound(ps::ParseState, op)
ret = parse_unary(ps, op)



str = "[:-\n:+]"