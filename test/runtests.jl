using TestItemRunner

include("iterate/test_iterators.jl")
include("iterate/test_selftest.jl")
include("parser/test_function_calls.jl")
include("parser/test_keyword_blocks.jl")
include("parser/test_modules.jl")
include("parser/test_operators.jl")
include("parser/test_parser.jl")
include("parser/test_square.jl")
include("parser/test_types.jl")
include("test_check_base.jl")
include("test_display.jl")
include("test_errparse.jl")
include("test_interface.jl")
include("test_spec.jl")

@run_package_tests
