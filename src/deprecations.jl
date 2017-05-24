function _check_dep_call(ps::ParseState, x::EXPR)
    if x.args[1] isa IDENTIFIER 
        fname = x.args[1].val
        if (fname == :write && length(x.args) == 2) ||
            fname == :ipermutedims ||
            fname == :$ && length(x.args) == 2 ||
            fname == :is ||
            fname == :midpoints ||
            fname == :den ||
            fname == :num ||
            fname == :takebuf_array ||
            fname == :takebuf_string ||
            fname == :sumabs ||
            fname == :sumabs2 ||
            fname == :minabs ||
            fname == :maxabs2 ||
            fname == :isimag ||
            fname == :bitbroadcast ||
            fname == :produce ||
            fname == :consume ||
            fname == :FloatRange
            push!(ps.diagnostics, Diagnostic{Diagnostics.Deprecation}(ps.nt.startbyte + (-x.span:0), [], ""))
        end
    end
end
