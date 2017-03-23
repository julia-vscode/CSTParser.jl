





# main programme
cd(Pkg.dir("ApproXD"))

include("src/ApproXD.jl")
include("test/test_Lininterp.jl")

# run individual tests
include("test/test_basics.jl")
include("test/test_approx.jl")
include("test/test_FSpaceXD.jl")


# run all tests: exits 
include("test/runtests.jl")


# do some profiling 
lbs = [1.0,2.0,-1]
ubs = [3.0,5.0,3]

gs = Array{Float64,1}[]
push!(gs, linspace(lbs[1],ubs[1],250))
push!(gs, linspace(lbs[2],ubs[2],48))
push!(gs, linspace(lbs[3],ubs[3],80))

myfun(i1,i2,i3) = i1 + 2*i2 + 3*i3

vs = Float64[ myfun(i,j,k) for i in gs[1], j in gs[2], k in gs[3] ]

l = ApproXD.Lininterp(vs,gs)

function pfun()
	for i in 1:1000000
		x = rand() * (ubs[1]-lbs[1]) + lbs[1]
		y = rand() * (ubs[2]-lbs[2]) + lbs[2]
		z = rand() * (ubs[3]-lbs[3]) + lbs[3]
		v = Float64[x,y,z]
		ApproXD.eval3D(l,v);
	end
end
@profile pfun()

