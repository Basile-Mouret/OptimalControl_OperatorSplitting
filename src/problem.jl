function all_data(A, B, c, Q, S, R, q, r, x_init; rho=50.0, alpha=1.0, eps_abs=1e-3, eps_rel=1e-3, reg=1e-6)
    Tv = promote_type(eltype(x_init), typeof(float(rho)))
    n = length(x_init)
    m = size(r, 1)
    T = size(c, 2)
    nc = (2 * n + m) * (T + 1)

    return all_data(
        n,
        m,
        T,
        nc,
        Tv(rho),
        Tv(alpha),
        Tv(eps_abs),
        Tv(eps_rel),
        Tv(reg),
        A,
        B,
        c,
        Q,
        S,
        R,
        q,
        r,
        x_init,
    )
end

function init_prob_vars(data::all_data{Tv}) where {Tv<:AbstractFloat}
    x = zeros(Tv, data.n, data.T + 1)
    u = zeros(Tv, data.m, data.T + 1)
    x_t = zeros(Tv, data.n, data.T + 1)
    u_t = zeros(Tv, data.m, data.T + 1)
    z = zeros(Tv, data.n, data.T + 1)
    y = zeros(Tv, data.m, data.T + 1)

    x_t[:, 1] = data.x_init
    return prob_vars(x, u, x_t, u_t, z, y)
end
