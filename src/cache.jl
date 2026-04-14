function _set_rhs_lower!(cache::solver_cache)
    data = cache.data
    rhs_lower = view(cache.rhs, (cache.dim_w + 1):data.nc)
    rhs_lower[1:data.n] .= data.x_init
    rhs_lower[(data.n + 1):end] .= vec(data.c)
    return nothing
end

"""
    setup_cache(data)

Build the reusable factorization and work buffers for repeated solves.
The cache stays valid while `A`, `B`, `Q`, `S`, `R`, `rho`, and `reg` stay fixed.
"""
function setup_cache(data::all_data)
    E = _assemble_E(data)
    G = _assemble_G(data)

    dim_w = (data.T + 1) * (data.n + data.m)
    dim_lambda = (data.T + 1) * data.n
    reg_block = -data.reg * sparse(I, dim_lambda, dim_lambda)
    KKT = [E  sparse(G');
           G  reg_block]

    cache = solver_cache(
        data,
        ldlt(Symmetric(KKT)),
        dim_w,
        zeros(eltype(data), data.nc),
        zeros(eltype(data), data.nc),
        zeros(eltype(data), data.n, data.T + 1),
        zeros(eltype(data), data.m, data.T + 1),
        zeros(eltype(data), data.n, data.T + 1),
        zeros(eltype(data), data.m, data.T + 1),
    )

    _set_rhs_lower!(cache)
    return cache
end
