"""
Package entry point.

Loads the core types, shared constructors, cache setup, utilities, and
solver API for the operator-splitting optimal-control implementation.
"""
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
include("utils.jl")
include("cache.jl")
include("solver.jl")

end
