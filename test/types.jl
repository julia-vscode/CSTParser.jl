facts("abstract") do
    strs =  ["abstract t"
            "abstract t{T}"
            "abstract t <: S"
            "abstract t{T} <: S"]
    for str in strs
        test_parse(str)
    end
end

facts("bitstype") do
    strs =  ["bitstype 64 Int"
            "bitstype 4*16 Int"]
    for str in strs
        test_parse(str)
    end
end

facts("typealias") do
    strs =  ["typealias name fsd"]
    for str in strs
        test_parse(str)
    end
end

facts("struct") do
    strs =  ["type a end"
            """type a
                arg1
            end"""
            """type a <: T
                arg1::Int
                arg2::Int
            end"""
            """type a
                arg1::T
            end"""
            """type a{T}
                arg1::T
                a(args) = new(args)
            end"""
             """type a <: Int
                arg1::Vector{Int}
             end"""
             """immutable a <: Int
                arg1::Vector{Int}
             end"""]
    for str in strs
        test_parse(str)
    end
end