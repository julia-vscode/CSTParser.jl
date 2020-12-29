# This deletes arbitrary tokens from files and checks that we can still parse them 
# and that iteration functions are still correctly ordered.

@testset "invalid jl file parsing" begin
    trav(x, f = x->nothing) = (f(x);for a in x trav(a, f) end)
    trav1(x, f = x->nothing) = (f(x);if x.args !== nothing;for a in x.args trav1(a, f) end;end)
    function check_err_parse(s, n = div(sizeof(s), 10))
        check_str(s) # parsing works?
        check_itr_order(s) # iteration produces same text?
    
        ts = collect(tokenize(s))[1:end-1]
        for i in 1:n
            length(ts) == 1 && return
            deleteat!(ts, rand(1:length(ts)))
            check_str(untokenize(ts))
        end
    end
    
    function check_str(s)
        try
            x = CSTParser.parse(s, true)
            trav(x)
        catch err
            throw(err)
        end
    end
    
    function check_dir(dir)
        for (root, dirs, files) in walkdir(dir)
            for f in files
                f = joinpath(root, f)
                (!isfile(f) || !endswith(f, ".jl")) && continue
                @info "checking edits to $f"
                s = String(read(f))
                if isvalid(s) && length(s) >0
                    check_err_parse(s, 1000)
                end
            end
        end
    end
    
    function get_segs(x) 
        offset = 0
        segs = []
        for i = 1:length(x)
            a = x[i]
            push!(segs, offset .+ (1:a.fullspan))
            offset += a.fullspan
        end
        segs
    end
    
    function check_itr_order(s, x = CSTParser.parse(s, true))
        length(x) == 0 && return
        segs = get_segs(x)
        s0 = join(String(codeunits(s)[seg]) for seg in segs)
        if s0 == s
            for i = 1:length(x)
                if length(x[i]) > 0
                    seg = segs[i]
                    s2 = String(codeunits(s)[seg])
                    check_itr_order(s2, x[i])
                end
            end
        else
            @info s
            @info s0
            error()
        end
    end

    check_dir("..")
end