using LinearAlgebra
using Random
using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

function robust_size_levels(size::String)
    if size == "small"
        return (n=10, m=10, p=5, T=30, rho=0.1)
    elseif size == "medium"
        return (n=30, m=30, p=10, T=60, rho=0.1)
    elseif size == "large"
        return (n=50, m=50, p=20, T=100, rho=0.1)
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

function solve_robust_state_estimation_ocp(; n::Int=30, m::Int=30, p::Int=10, T::Int=60, max_iters::Int=3000, rho::Float64=0.1, seed::Int=0)
    phi, A, B, c, x0, M, ym, _ = robust_state_estimation_data(n, m, p, T; seed=seed)
    prox_operator! = robust_proximal_factory!(M)

    data = OptimalControl_OperatorSplitting.all_data(A, B, c, phi[1], phi[2], phi[3], phi[4], phi[5], x0; rho=rho, alpha=1.8)
    cache = OptimalControl_OperatorSplitting.setup_cache(data)
    x_opt, u_opt, tt = OptimalControl_OperatorSplitting.solve(cache, prox_operator!; max_iters=max_iters)

    return x_opt, u_opt, ym, tt
end

function solve_robust_state_estimation_size(size::String; max_iters::Int=3000, seed::Int=0)
    sizes = robust_size_levels(size)
    return solve_robust_state_estimation_ocp(
        n=sizes.n,
        m=sizes.m,
        p=sizes.p,
        T=sizes.T,
        max_iters=max_iters,
        rho=sizes.rho,
        seed=seed,
    )
end

function main()
    size = parse_size_arg()
    println("Running robust state estimation ($size)")
    _, _, _, tt = solve_robust_state_estimation_size(size)
    display(tt)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
