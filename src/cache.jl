#=
Cache construction.

Builds the reusable KKT factorization and persistent work buffers used for
cold starts and repeated warm-started solves.
=#
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
"""
function setup_cache(data::all_data)
    dim_w = (data.T + 1) * (data.n + data.m)
    rhs = zeros(eltype(data), data.nc)
    sol = similar(rhs)
    rhs_top = reshape(view(rhs, 1:dim_w), data.n + data.m, data.T + 1)
    rhs_lower = view(rhs, (dim_w + 1):data.nc)
    sol_top = reshape(view(sol, 1:dim_w), data.n + data.m, data.T + 1)
    vars = prob_vars(data)

    cache = solver_cache(
        data,
        vars,
        ldlt(_assemble_kkt(data)),
        rhs,
        sol,
        rhs_top,
        rhs_lower,
        sol_top,
        zeros(eltype(data), data.n, data.T + 1),
        zeros(eltype(data), data.m, data.T + 1),
        zeros(eltype(data), data.n, data.T + 1),
        zeros(eltype(data), data.m, data.T + 1),
    )

    _set_rhs_lower!(cache)
    return cache
end
