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
