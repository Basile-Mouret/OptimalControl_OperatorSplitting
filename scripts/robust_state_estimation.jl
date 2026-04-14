using LinearAlgebra
using Random
using BenchmarkTools
using OptimalControl_OperatorSplitting

function robust_size_levels(size::String)
    if size == "small"
        return 10, 10, 5, 30
    elseif size == "medium"
        return 30, 30, 10, 60
    elseif size == "large"
        return 50, 50, 20, 100
    else
        error("Invalid size. Choose from 'small', 'medium', or 'large'.")
    end
end

"""
Generate one robust state estimation instance following `rob_est/gen_data.m`.

Returns:
- phi = (Q, S, R, q, r)
- system matrices A, B, c
- initial state x0
- robust Huber parameter M
- synthetic measurements ym
"""
function robust_state_estimation_data(n::Int, m::Int, p::Int, T::Int; seed::Int=0)
    Random.seed!(seed)

    rho_default = 0.1

    x0 = 10.0 .* randn(n)
    c = zeros(n, T)

    A = 2.0 .* randn(n, n)
    A ./= (maximum(abs.(eigvals(A))) + 0.1)
    # The OSC table uses m = n, but we keep m explicit in the API.
    # For the benchmark sizes, this gives B = I_n.
    B = Matrix{Float64}(I, n, m)

    C = randn(p, n)
    C ./= maximum(C)

    # Generate outlier-corrupted process noise used to simulate measurements.
    u = randn(m, T + 1)
    prob = 0.25
    k_outliers = round(Int, prob * (T + 1))
    ts_perturbed = sort(randperm(T + 1)[1:k_outliers])
    u[:, ts_perturbed] .+= 10.0 .* randn(m, k_outliers)

    sig = 1.0
    v_meas = sqrt(sig) .* randn(p, T + 1)

    x_true = zeros(n, T + 1)
    ym = zeros(p, T + 1)
    x_true[:, 1] = x0
    for t in 1:T
        ym[:, t] = C * x_true[:, t] + v_meas[:, t]
        x_true[:, t + 1] = A * x_true[:, t] + B * u[:, t]
    end
    ym[:, T + 1] = C * x_true[:, T + 1] + v_meas[:, T + 1]

    # Objective split used by OSC:
    # 0.5*||y - Cx||^2 goes to phi (quadratic + linear in x),
    # 0.5*huber_circ(u, M) goes to psi (handled by the prox operator).
    Q = C' * C
    S = zeros(n, m)
    R = zeros(m, m)

    q = zeros(n, T + 1)
    for t in 1:(T + 1)
        q[:, t] .= -(C' * ym[:, t])
    end
    r = zeros(m, T + 1)

    phi = (Q, S, R, q, r)
    M = 1.0

    return phi, A, B, c, x0, M, ym, rho_default
end

"""
Proximal operator for robust state estimation (matches OSC C code):

for each stage t,
    x_tilde[:, t] = v[:, t]
    u_tilde[:, t] = fac * w[:, t]

where
    fac = 1 - min(1/(1+rho), M/(rho*||w[:, t]||_2)).
"""
function robust_proximal_factory!(M::Float64)
    function robust_proximal!(x_tilde, u_tilde, v, w, rho)
        m, num_steps = size(w)

        x_tilde .= v

        @inbounds for t in 1:num_steps
            nm = norm(view(w, :, t), 2)
            second_term = nm == 0.0 ? Inf : M / (rho * nm)
            fac = 1.0 - min(1.0 / (1.0 + rho), second_term)

            for j in 1:m
                u_tilde[j, t] = fac * w[j, t]
            end
        end

        return nothing
    end

    return robust_proximal!
end

function solve_robust_state_estimation_ocp(; n::Int=30, m::Int=30, p::Int=10, T::Int=60, max_iters::Int=200, rho::Float64=0.1, seed::Int=0)
    phi, A, B, c, x0, M, ym, _ = robust_state_estimation_data(n, m, p, T; seed=seed)
    prox_operator! = robust_proximal_factory!(M)

    x_opt, u_opt = OptimalControl_OperatorSplitting.solve_ocp(
        phi,
        prox_operator!,
        A,
        B,
        c,
        x0,
        T;
        max_iters=max_iters,
        rho=rho,
    )

    return x_opt, u_opt, ym
end

function solve_robust_state_estimation_size(size::String; max_iters::Int=200, rho::Float64=0.1, seed::Int=0)
    n, m, p, T = robust_size_levels(size)
    return solve_robust_state_estimation_ocp(n=n, m=m, p=p, T=T, max_iters=max_iters, rho=rho, seed=seed)
end

println("Benchmarking Robust State Estimation... (Small: n=10, m=10, p=5, T=30)")
@btime solve_robust_state_estimation_size("small")

println("Benchmarking Robust State Estimation... (Medium: n=30, m=30, p=10, T=60)")
@btime solve_robust_state_estimation_size("medium")

println("Benchmarking Robust State Estimation... (Large: n=50, m=50, p=20, T=100)")
@btime solve_robust_state_estimation_size("large")