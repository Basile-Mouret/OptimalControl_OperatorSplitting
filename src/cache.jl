#=
Cache construction.

Builds the reusable KKT factorization and persistent work buffers used for
cold starts and repeated warm-started solves.
=#
"""
    _set_rhs_lower!(cache)

Refresh the dynamics portion of the linear-system right-hand side from
`x_init` and `c`.

This is called before each solve so changing `q`, `r`, `c`, or `x_init`
does not require rebuilding the factorization.
"""
function _set_rhs_lower!(cache::solver_cache)
    data = cache.data
    copyto!(cache.rhs_lower, 1, data.x_init, 1, data.n)
    copyto!(cache.rhs_lower, data.n + 1, data.c, 1, length(data.c))
    return nothing
end

"""
    setup_cache(data)

Build the reusable factorization and work buffers for repeated solves.
The cache stays valid while `A`, `B`, `Q`, `S`, `R`, `rho`, and `reg` stay fixed.

This function factorizes the static KKT matrix once and allocates all vectors
used in the ADMM loop, including iterate storage for warm starts.
"""
function setup_cache(data::all_data)
    dim_w = (data.T + 1) * (data.n + data.m)
    nx = data.n * (data.T + 1)
    nu = data.m * (data.T + 1)
    rhs = zeros(eltype(data), data.nc)
    sol = similar(rhs)
    rhs_lower = view(rhs, (dim_w + 1):data.nc)
    vars = prob_vars(data)

    cache = solver_cache(
        data,
        vars,
        ldlt(_assemble_kkt(data)),
        rhs,
        sol,
        rhs_lower,
        zeros(eltype(data), nx),
        zeros(eltype(data), nu),
        zeros(eltype(data), nx),
        zeros(eltype(data), nu),
    )

    _set_rhs_lower!(cache)
    return cache
end
