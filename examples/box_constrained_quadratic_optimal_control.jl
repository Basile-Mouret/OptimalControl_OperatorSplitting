#=
Box-constrained quadratic optimal-control example.

Builds a random box-constrained problem and solves it with the analytical
proximal step.
=#
using LinearAlgebra
using Random
using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

function box_size_levels(size::String)
    if size == "small"
        return (n=4, m=2, T=20, rho=50.0)
    elseif size == "medium"
        return (n=10, m=4, T=40, rho=50.0)
    elseif size == "large"
        return (n=20, m=8, T=80, rho=50.0)
    else
        error("Invalid size. Choose from 'small', 'medium', or 'large'.")
    end
end

function box_constrained_quadratic_ocp(n, m, T; seed=0)
    Random.seed!(seed)

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

function build_box_constrained_data(; n=4, m=2, T=20, rho=50.0, seed=0)
    A, B, c, Q, S, R, q, r, x0 = box_constrained_quadratic_ocp(n, m, T; seed=seed)
    return all_data(A, B, c, Q, S, R, q, r, x0; rho=rho)
end

function build_box_constrained_cache(; n=4, m=2, T=20, rho=50.0, seed=0)
    data = build_box_constrained_data(n=n, m=m, T=T, rho=rho, seed=seed)
    return setup_cache(data)
end

function solve_box_constrained_ocp(cache; max_iters=50)
    return solve(cache, box_proximal!; max_iters=max_iters)
end

function solve_box_constrained_ocp(; n=4, m=2, T=20, max_iters=50, rho=50.0, seed=0)
    cache = build_box_constrained_cache(n=n, m=m, T=T, rho=rho, seed=seed)
    return solve_box_constrained_ocp(cache; max_iters=max_iters)
end

function main()
    size = parse_size_arg()
    sizes = box_size_levels(size)

    println("Running box-constrained quadratic optimal control ($size)")
    _, _, tt = solve_box_constrained_ocp(
        n=sizes.n,
        m=sizes.m,
        T=sizes.T,
        rho=sizes.rho,
    )
    display(tt)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
