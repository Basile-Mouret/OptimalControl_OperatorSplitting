#=
Box-constrained quadratic optimal-control example.

Builds a small toy problem, solves it with the analytical box proximal step,
and also provides an Ipopt-based proximal step for comparison.
=#
using BenchmarkTools
using Ipopt
using JuMP
using LinearAlgebra
using OptimalControl_OperatorSplitting

function box_constrained_quadratic_ocp(n, m, T)
    A_rand = randn(n, n)
    B = randn(n, m)

    max_eig = maximum(abs.(eigvals(A_rand)))
    A = A_rand ./ max_eig

    c = zeros(n, T)
    x0 = randn(n) * 10.0

    Q = Matrix(1.0 * I(n))
    R = Matrix(0.1 * I(m))
    S = zeros(n, m)

    q = zeros(n, T + 1)
    r = zeros(m, T + 1)

    return A, B, c, Q, S, R, q, r, x0
end

function box_proximal!(x_tilde, u_tilde, v, w, rho)
    x_tilde .= v
    u_tilde .= clamp.(w, -1.0, 1.0)
end

function ipopt_box_proximal!(x_tilde, u_tilde, v, w, rho)
    n, num_steps = size(v)
    m = size(w, 1)

    Threads.@threads for t in 1:num_steps
        model = Model(Ipopt.Optimizer)
        set_silent(model)

        @variable(model, xt[1:n])
        @variable(model, ut[1:m])
        @constraint(model, -1.0 .<= ut .<= 1.0)
        @objective(model, Min,
            (rho / 2.0) * (
                sum((xt[i] - v[i, t])^2 for i in 1:n) +
                sum((ut[j] - w[j, t])^2 for j in 1:m)
            )
        )

        optimize!(model)
        x_tilde[:, t] .= value.(xt)
        u_tilde[:, t] .= value.(ut)
    end
end

function build_box_constrained_data(; n=4, m=2, T=20, rho=50.0)
    A, B, c, Q, S, R, q, r, x0 = box_constrained_quadratic_ocp(n, m, T)
    return all_data(A, B, c, Q, S, R, q, r, x0; rho=rho)
end

function build_box_constrained_cache(; n=4, m=2, T=20, rho=50.0)
    data = build_box_constrained_data(n=n, m=m, T=T, rho=rho)
    return setup_cache(data)
end

function solve_box_constrained_ocp(cache; max_iters=50)
    return solve(cache, box_proximal!; max_iters=max_iters)
end

function solve_box_constrained_ocp(; max_iters=50, rho=50.0)
    cache = build_box_constrained_cache(rho=rho)
    return solve_box_constrained_ocp(cache; max_iters=max_iters)
end

function solve_box_constrained_ocp_ipopt(cache; max_iters=50)
    return solve(cache, ipopt_box_proximal!; max_iters=max_iters)
end

function solve_box_constrained_ocp_ipopt(; max_iters=50, rho=50.0)
    cache = build_box_constrained_cache(rho=rho)
    return solve_box_constrained_ocp_ipopt(cache; max_iters=max_iters)
end

function main()
    analytical_cache = build_box_constrained_cache()
    ipopt_cache = build_box_constrained_cache()

    println("Benchmarking analytical proximal step...")
    @btime solve_box_constrained_ocp($analytical_cache)
    _, _, tt = solve_box_constrained_ocp(analytical_cache)
    println(tt)

    println("\nBenchmarking Ipopt proximal step...")
    @btime solve_box_constrained_ocp_ipopt($ipopt_cache)
    _, _, tt_ipopt = solve_box_constrained_ocp_ipopt(ipopt_cache)
    println(tt_ipopt)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
