"""
    OptimalControl_OperatorSplitting

Operator-splitting solver core for finite-horizon optimal control.

The package keeps `src/` solver-only, with problem-specific proximal logic
provided by user code. The public API is cache-first (`setup_cache` then
`solve`) so KKT factorizations and ADMM state can be reused across calls.
"""
module OptimalControl_OperatorSplitting

using LinearAlgebra
using SparseArrays
using SuiteSparse

export Timings
export all_data
export setup_cache
export solve

include("types.jl")
include("utils.jl")
include("cache.jl")
include("solver.jl")

end
