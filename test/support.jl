identity_prox!(x_tilde, u_tilde, v, w, rho) = (x_tilde .= v; u_tilde .= w; nothing)

box_prox!(x_tilde, u_tilde, v, w, rho) = (x_tilde .= v; u_tilde .= clamp.(w, -1.0, 1.0); nothing)

stage_block(data::AbstractMatrix, _) = data
stage_block(data::AbstractArray{<:Any,3}, stage) = @view data[:, :, stage]

max_abs_diff(A, B) = maximum(abs.(A .- B))

function build_zero_problem(; rho=1.0, alpha=1.0, eps_abs=1e-3, eps_rel=1e-3)
    A = zeros(1, 1)
    B = zeros(1, 1)
    c = zeros(1, 1)
    Q = zeros(1, 1)
    S = zeros(1, 1)
    R = zeros(1, 1)
    q = zeros(1, 2)
    r = zeros(1, 2)
    x_init = zeros(1)

    return all_data(A, B, c, Q, S, R, q, r, x_init; rho=rho, alpha=alpha, eps_abs=eps_abs, eps_rel=eps_rel)
end

function build_stage_varying_unconstrained_problem(; rho=5.0, alpha=1.0, eps_abs=1e-7, eps_rel=1e-7)
    n = 2
    m = 1
    T = 3

    A = zeros(n, n, T)
    A[:, :, 1] .= [0.80 0.10; 0.00 0.90]
    A[:, :, 2] .= [0.85 0.00; 0.05 0.92]
    A[:, :, 3] .= [0.82 0.03; 0.01 0.88]

    B = zeros(n, m, T)
    B[:, :, 1] .= reshape([0.50, 0.20], n, m)
    B[:, :, 2] .= reshape([0.55, 0.15], n, m)
    B[:, :, 3] .= reshape([0.45, 0.25], n, m)

    Q = zeros(n, n, T + 1)
    Q[:, :, 1] .= [1.0 0.1; 0.1 2.0]
    Q[:, :, 2] .= [1.2 0.0; 0.0 2.1]
    Q[:, :, 3] .= [1.1 -0.05; -0.05 2.3]
    Q[:, :, 4] .= [1.4 0.0; 0.0 2.4]

    S = zeros(n, m, T + 1)
    S[:, :, 1] .= reshape([0.05, -0.02], n, m)
    S[:, :, 2] .= reshape([0.02, 0.01], n, m)
    S[:, :, 3] .= reshape([-0.03, 0.04], n, m)
    S[:, :, 4] .= reshape([0.01, 0.00], n, m)

    R = zeros(m, m, T + 1)
    R[:, :, 1] .= reshape([0.6], m, m)
    R[:, :, 2] .= reshape([0.7], m, m)
    R[:, :, 3] .= reshape([0.8], m, m)
    R[:, :, 4] .= reshape([0.9], m, m)

    q = [0.2 -0.1 0.1 0.0;
         -0.3 0.0 0.1 0.2]
    r = reshape([0.1, -0.2, 0.0, 0.05], 1, T + 1)
    c = [0.1 -0.2 0.0;
         0.0 0.1 -0.1]
    x_init = [1.0, -0.5]

    return all_data(A, B, c, Q, S, R, q, r, x_init; rho=rho, alpha=alpha, eps_abs=eps_abs, eps_rel=eps_rel)
end

function build_box_constrained_problem(; rho=20.0, alpha=1.8, eps_abs=1e-6, eps_rel=1e-6)
    A = [0.9 0.1; 0.0 0.95]
    B = reshape([0.5, 0.2], 2, 1)
    c = [0.1 -0.2 0.0;
         0.0 0.1 -0.1]

    Q = [1.0 0.0; 0.0 2.0]
    S = zeros(2, 1)
    R = reshape([0.4], 1, 1)

    q = [0.2 -0.1 0.1 0.0;
         -0.3 0.0 0.1 0.2]
    r = reshape([0.1, -0.2, 0.0, 0.05], 1, 4)
    x_init = [1.0, -0.5]

    return all_data(A, B, c, Q, S, R, q, r, x_init; rho=rho, alpha=alpha, eps_abs=eps_abs, eps_rel=eps_rel)
end

function perturb_linear_terms!(data::all_data)
    data.q .+= [0.05 -0.02 0.03 -0.01;
                -0.01 0.02 -0.03 0.04]
    data.r .+= reshape([0.02, -0.01, 0.03, -0.02], size(data.r))
    data.c .+= [0.01 0.00 -0.02;
                -0.01 0.02 0.01]
    data.x_init .+= [0.05, -0.03]
    return nothing
end

function solve_reference_with_ipopt(data::all_data; u_lower=nothing, u_upper=nothing)
    n = data.n
    m = data.m
    T = data.T

    model = Model(Ipopt.Optimizer)
    set_silent(model)

    @variable(model, x[1:n, 1:T+1])
    @variable(model, u[1:m, 1:T+1])

    if u_lower !== nothing
        @constraint(model, u .>= u_lower)
    end
    if u_upper !== nothing
        @constraint(model, u .<= u_upper)
    end

    @constraint(model, x[:, 1] .== data.x_init)

    for t in 1:T
        A_t = stage_block(data.A, t)
        B_t = stage_block(data.B, t)
        @constraint(
            model,
            [i in 1:n],
            x[i, t + 1] ==
                sum(A_t[i, j] * x[j, t] for j in 1:n) +
                sum(B_t[i, j] * u[j, t] for j in 1:m) +
                data.c[i, t],
        )
    end

    @objective(model, Min,
        sum(
            0.5 * sum(x[i, t] * stage_block(data.Q, t)[i, j] * x[j, t] for i in 1:n, j in 1:n) +
            sum(x[i, t] * stage_block(data.S, t)[i, j] * u[j, t] for i in 1:n, j in 1:m) +
            0.5 * sum(u[i, t] * stage_block(data.R, t)[i, j] * u[j, t] for i in 1:m, j in 1:m) +
            sum(data.q[i, t] * x[i, t] for i in 1:n) +
            sum(data.r[j, t] * u[j, t] for j in 1:m)
            for t in 1:T+1
        )
    )

    optimize!(model)
    return value.(x), value.(u)
end
