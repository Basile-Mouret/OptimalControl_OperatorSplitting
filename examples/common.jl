using SparseArrays
using Random

function parse_size_arg(; default="small")
    size = isempty(ARGS) ? default : lowercase(ARGS[1])

    if size != "small" && size != "medium" && size != "large"
        error("Invalid size `$size`. Choose from `small`, `medium`, or `large`.")
    end

    return size
end

fixture_path(example::String, size::String, name::String) =
    joinpath(@__DIR__, "..", "osc", example, "data", size, name)

fixture_tokens(example::String, size::String, name::String) =
    split(read(fixture_path(example, size, name), String))

function load_c_fixture_data(example::String, size::String; eps_abs=1e-3, eps_rel=1e-3)
    open(fixture_path(example, size, "data_KKT"), "r") do io
        header = split(readline(io))
        n = parse(Int, header[1])
        m = parse(Int, header[2])
        T = parse(Int, header[3])
        nnz = parse(Int, header[4])
        rho = parse(Float64, header[5])
        alpha = parse(Float64, header[6])

        x_init = parse.(Float64, split(readline(io)))
        Ar = parse.(Int, split(readline(io))) .+ 1
        Ap = parse.(Int, split(readline(io))) .+ 1
        Ax = parse.(Float64, split(readline(io)))
        rhs = parse.(Float64, split(readline(io)))

        nc = length(rhs)
        @assert length(Ar) == nnz
        @assert length(Ax) == nnz
        @assert length(Ap) == nc + 1

        KKT = SparseMatrixCSC{Float64, Int}(nc, nc, Ap, Ar, Ax)

        dim_w = (T + 1) * (n + m)
        dim_lambda = (T + 1) * n

        top = -reshape(rhs[1:dim_w], n + m, T + 1)
        q = copy(top[1:n, :])
        r = copy(top[(n + 1):end, :])

        lower = rhs[(dim_w + 1):end]
        x_init_rhs = copy(lower[1:n])
        c = reshape(copy(lower[(n + 1):end]), n, T)

        Q = zeros(Float64, n, n, T + 1)
        S = zeros(Float64, n, m, T + 1)
        R = zeros(Float64, m, m, T + 1)
        A = zeros(Float64, n, n, T)
        B = zeros(Float64, n, m, T)

        for stage in 1:(T + 1)
            start = (stage - 1) * (n + m) + 1
            stop = stage * (n + m)
            E_t = Matrix(KKT[start:stop, start:stop])

            Q[:, :, stage] .= E_t[1:n, 1:n]
            S[:, :, stage] .= E_t[1:n, (n + 1):end]
            R[:, :, stage] .= E_t[(n + 1):end, (n + 1):end]

            @inbounds for i in 1:n
                Q[i, i, stage] -= rho
            end
            @inbounds for i in 1:m
                R[i, i, stage] -= rho
            end
        end

        for stage in 1:T
            row_start = dim_w + stage * n + 1
            row_stop = dim_w + (stage + 1) * n
            col_start = (stage - 1) * (n + m) + 1
            col_stop = stage * (n + m)
            G_t = Matrix(KKT[row_start:row_stop, col_start:col_stop])

            A[:, :, stage] .= -G_t[:, 1:n]
            B[:, :, stage] .= -G_t[:, (n + 1):end]
        end

        reg = -KKT[dim_w + 1, dim_w + 1]

        return all_data(
            A,
            B,
            c,
            Q,
            S,
            R,
            q,
            r,
            x_init_rhs;
            rho=rho,
            alpha=alpha,
            eps_abs=eps_abs,
            eps_rel=eps_rel,
            reg=reg,
        )
    end
end

function perturb_x_init_uniform!(data::all_data, x_init_ref::AbstractVector, rng::Random.AbstractRNG; sigma=0.1)
    @inbounds for i in eachindex(x_init_ref)
        data.x_init[i] = x_init_ref[i] * (1 + sigma * (2 * rand(rng) - 1))
    end
    return nothing
end

function perturb_x_init_gaussian!(data::all_data, x_init_ref::AbstractVector, rng::Random.AbstractRNG; sigma=0.1)
    @inbounds for i in eachindex(x_init_ref)
        data.x_init[i] = x_init_ref[i] + sigma * randn(rng)
    end
    return nothing
end

uniform_perturbation(; sigma=0.1) = (data, x_init_ref, rng) -> perturb_x_init_uniform!(data, x_init_ref, rng; sigma=sigma)
gaussian_perturbation(; sigma=0.1) = (data, x_init_ref, rng) -> perturb_x_init_gaussian!(data, x_init_ref, rng; sigma=sigma)

function reset_cache!(cache)
    vars = cache.vars
    fill!(vars.x, 0.0)
    fill!(vars.u, 0.0)
    fill!(vars.x_t, 0.0)
    fill!(vars.u_t, 0.0)
    fill!(vars.z, 0.0)
    fill!(vars.y, 0.0)
    copyto!(vars.x_t, 1, cache.data.x_init, 1, cache.data.n)
    nothing
end

function copy_warm_start!(dest_cache, src_cache)
    copyto!(dest_cache.vars.x_t, src_cache.vars.x_t)
    copyto!(dest_cache.vars.u_t, src_cache.vars.u_t)
    copyto!(dest_cache.vars.z, src_cache.vars.z)
    copyto!(dest_cache.vars.y, src_cache.vars.y)
    nothing
end

function run(data::all_data, prox_operator!, perturb!; max_iters=3000, num_cold=100, num_warm=100, seed=0)
    num_cold < 1 && error("num_cold must be at least 1")
    num_warm < 1 && error("num_warm must be at least 1")

    cold_cache = setup_cache(data)
    cold_total = 0.0
    cold_lin = 0.0
    cold_prox = 0.0
    cold_worst = 0.0
    cold_iters = 0
    cold_last = Timings{eltype(data)}()

    for _ in 1:num_cold
        reset_cache!(cold_cache)
        _, _, tt = solve(cold_cache, prox_operator!; max_iters=max_iters)
        cold_total += tt.total_time / num_cold
        cold_lin += tt.lin_sys_time / num_cold
        cold_prox += tt.prox_time / num_cold
        cold_worst = max(cold_worst, tt.total_time)
        cold_iters = tt.itns
        cold_last = tt
    end

    warm_cache = setup_cache(data)
    reset_cache!(warm_cache)
    x_init_ref = copy(data.x_init)
    rng = MersenneTwister(seed)

    warm_total = 0.0
    warm_lin = 0.0
    warm_prox = 0.0
    warm_worst = 0.0
    warm_iters = 0.0
    warm_last = Timings{eltype(data)}()

    for _ in 1:num_warm
        perturb!(data, x_init_ref, rng)
        copy_warm_start!(warm_cache, cold_cache)
        _, _, tt = solve(warm_cache, prox_operator!; max_iters=max_iters)
        warm_total += tt.total_time / num_warm
        warm_lin += tt.lin_sys_time / num_warm
        warm_prox += tt.prox_time / num_warm
        warm_worst = max(warm_worst, tt.total_time)
        warm_iters += tt.itns / num_warm
        warm_last = tt
    end

    data.x_init .= x_init_ref

    return (
        cold=(
            iters=cold_iters,
            total_ms=cold_total,
            lin_ms=cold_lin,
            prox_ms=cold_prox,
            worst_ms=cold_worst,
            tt=cold_last,
        ),
        warm=(
            iters=warm_iters,
            total_ms=warm_total,
            lin_ms=warm_lin,
            prox_ms=warm_prox,
            worst_ms=warm_worst,
            tt=warm_last,
        ),
    )
end

function print_run(stats; num_cold=100, num_warm=100)
    println("Running ", num_cold, " cold starts")
    println("COLD START:")
    println("Iterations ", stats.cold.iters)
    println("Taking (on average) ", round(stats.cold.total_ms; digits=2), " ms")
    println("Average time to solve linear system: ", round(stats.cold.lin_ms; digits=2), " ms")
    println("Average time to take prox step: ", round(stats.cold.prox_ms; digits=4), " ms")
    println("Worst case total solve time: ", round(stats.cold.worst_ms; digits=2), " ms")
    println("RUNNING ", num_warm, " WARM STARTS")
    println("COMPLETE")
    println("Average num iterations ", round(stats.warm.iters; digits=2))
    println("Taking an average of ", round(stats.warm.total_ms; digits=2), " ms")
    println("Average time to solve linear system: ", round(stats.warm.lin_ms; digits=2), " ms")
    println("Average time to take prox step: ", round(stats.warm.prox_ms; digits=4), " ms")
    println("Worst case time to solve: ", round(stats.warm.worst_ms; digits=4), " ms")
    return nothing
end
