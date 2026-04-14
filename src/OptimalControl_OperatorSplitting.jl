module OptimalControl_OperatorSplitting

using LinearAlgebra
using SparseArrays
using SuiteSparse

export Timings
export all_data
export prob_vars
export setup_cache
export solve
export solve!
export solver_cache

include("types.jl")
include("problem.jl")
include("cache.jl")
include("solver.jl")

end
