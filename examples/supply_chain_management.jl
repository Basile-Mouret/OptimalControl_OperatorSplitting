using LinearAlgebra
using Random
using BenchmarkTools
using OptimalControl_OperatorSplitting

function supply_chain_size_levels(size::String)
    if size == "small"
        return 5, 20, 2, 2, 0.6, 2.5
    elseif size == "medium"
        return 20, 20, 2, 2, 0.4, 2.5
    elseif size == "large"
        return 40, 20, 2, 2, 0.3, 2.5
    else
        error("Invalid size. Choose from 'small', 'medium', or 'large'.")
    end
end

function _is_connected_undirected(adj::BitMatrix)
    n = size(adj, 1)
    visited = falses(n)
    queue = Vector{Int}(undef, n)
    head = 1
    tail = 1

    queue[tail] = 1
    visited[1] = true

    while head <= tail
        v = queue[head]
        head += 1

        @inbounds for u in 1:n
            if adj[v, u] && !visited[u]
                tail += 1
                queue[tail] = u
                visited[u] = true
            end
        end
    end

    return all(visited)
end

"""
Generate one supply-chain management instance following `sup_ch/gen_data.m`.

Returns:
- phi = (Q, S, R, q, r)
- system matrices A, B, c
- initial state x0
- proximal data C, U, idx_source, idx_depart
"""
function supply_chain_data(n::Int, T::Int, numsource::Int, numsink::Int, dist::Float64; seed::Int=0)
    Random.seed!(seed)

    # Build a random geometric graph that includes warehouses, sources, and sinks.
    position_nodes = rand(2, n)
    source_pos = 0.1 .* rand(2, numsource)
    sink_pos = 0.9 .+ 0.1 .* rand(2, numsink)
    position = hcat(position_nodes, source_pos, sink_pos)

    n_total = size(position, 2)
    d = zeros(n_total, n_total)
    for i in 1:n_total
        for j in 1:n_total
            d[i, j] = norm(view(position, :, i) - view(position, :, j), 2)
        end
    end

    d[d .> dist] .= 0.0
    d[(n + 1):(n + numsource), (n + 1):(n + numsource)] .= 0.0
    d[(n + numsource + 1):end, (n + numsource + 1):end] .= 0.0

    # Connectivity test on the full undirected graph.
    adj = BitMatrix(d .> 0.0)
    adj .|= adj'
    if !_is_connected_undirected(adj)
        error("Graph is not connected. Try a larger dist or a different seed.")
    end

    # Build edge-incidence structure used by OSC.
    edges = d[1:n, 1:n]
    edge_pairs = findall(!iszero, edges)
    m_warehouse = length(edge_pairs)

    Bminus1 = zeros(n, m_warehouse)
    Bplus1 = zeros(n, m_warehouse)
    v_dist = zeros(m_warehouse)
    for (k, idx) in enumerate(edge_pairs)
        i, j = Tuple(idx)
        Bminus1[i, k] = 1.0
        Bplus1[j, k] = 1.0
        v_dist[k] = edges[i, j]
    end

    sink_pairs = findall(!iszero, d[1:n, (n + numsource + 1):end])
    a_snk = [Tuple(id)[1] for id in sink_pairs]
    d_sink = [d[Tuple(id)[1], n + numsource + Tuple(id)[2]] for id in sink_pairs]
    sink = zeros(n, length(a_snk))
    for i in 1:length(a_snk)
        sink[a_snk[i], i] = 1.0
    end

    src_pairs = findall(!iszero, d[1:n, (n + 1):(n + numsource)])
    a_src = [Tuple(id)[1] for id in src_pairs]
    d_source = [d[Tuple(id)[1], n + Tuple(id)[2]] for id in src_pairs]
    source = zeros(n, length(a_src))
    for i in 1:length(a_src)
        source[a_src[i], i] = 1.0
    end

    Bplus = hcat(source, Bplus1, zeros(n, length(a_snk)))
    Bminus = hcat(zeros(n, length(a_src)), Bminus1, sink)
    B = Bplus - Bminus

    m = size(B, 2)
    distances = vcat(d_source, v_dist, d_sink)

    idx_source = findall(j -> sum(@view B[:, j]) == 1.0, 1:m)
    idx_depart = [findall(!iszero, @view Bminus[i, :]) for i in 1:n]

    C = 2.0
    Ub = 1.0

    A = Matrix{Float64}(I, n, n)
    c = zeros(n, T)

    q_t = 0.5 .* rand(n)
    q_vec = 0.5 .* rand(n)
    r_vec = max.(distances .+ 0.02 .* randn(m), 0.0)

    if !isempty(a_snk)
        r_vec[(end - length(a_snk) + 1):end] .= -15.0 .* (0.1 .* rand(length(a_snk)) .+ 1.0)
    end
    if !isempty(a_src)
        r_vec[1:length(a_src)] .= 5.0 .* (0.1 .* rand(length(a_src)) .+ 1.0)
    end

    x0 = (C / 2.0) .* ones(n)

    Q = 2.0 .* Diagonal(q_t)
    S = zeros(n, m)
    R = zeros(m, m)
    q = repeat(q_vec, 1, T + 1)
    r = repeat(r_vec, 1, T + 1)

    phi = (Q, S, R, q, r)

    return phi, A, B, c, x0, C, Ub, idx_source, idx_depart
end

function _test_lambda!(wi::Vector{Float64}, w_stage::AbstractVector{Float64}, v::Float64, idxs::Vector{Int}, C::Float64, U::Float64, lambda::Float64)
    sumu = 0.0
    @inbounds for k in eachindex(idxs)
        val = clamp(w_stage[idxs[k]] - lambda, 0.0, U)
        wi[k] = val
        sumu += val
    end
    vi = clamp(v + lambda, 0.0, C)
    return sumu, vi
end

function _bisection_node!(u_stage::AbstractVector{Float64}, x_val::Base.RefValue{Float64}, idxs::Vector{Int}, C::Float64, U::Float64)
    isempty(idxs) && return nothing

    wi = zeros(length(idxs))
    lambda = 0.0
    lambda_old = 0.0

    sumu, vi = _test_lambda!(wi, u_stage, x_val[], idxs, C, U, lambda)
    if sumu > vi
        lambda = 1.0
        sumu, vi = _test_lambda!(wi, u_stage, x_val[], idxs, C, U, lambda)
        while sumu > vi
            lambda_old = lambda
            lambda *= 2.0
            sumu, vi = _test_lambda!(wi, u_stage, x_val[], idxs, C, U, lambda)
        end
    end

    low = lambda_old
    up = lambda
    eps = 1e-3

    while (up - low) > eps
        lambda = 0.5 * (low + up)
        sumu, vi = _test_lambda!(wi, u_stage, x_val[], idxs, C, U, lambda)
        if sumu <= vi
            up = lambda
        else
            low = lambda
        end
    end

    @inbounds for k in eachindex(idxs)
        u_stage[idxs[k]] = wi[k]
    end
    x_val[] = vi

    return nothing
end

"""
Proximal operator for supply-chain management (matches OSC C code).
"""
function supply_chain_proximal_factory!(C::Float64, U::Float64, idx_source::Vector{Int}, idx_depart::Vector{Vector{Int}})
    function supply_chain_proximal!(x_tilde, u_tilde, v, w, rho)
        n, num_steps = size(v)

        x_tilde .= v
        u_tilde .= w

        @inbounds for t in 1:num_steps
            for j in idx_source
                u_tilde[j, t] = clamp(u_tilde[j, t], 0.0, U)
            end

            for i in 1:n
                xref = Ref(x_tilde[i, t])
                _bisection_node!(view(u_tilde, :, t), xref, idx_depart[i], C, U)
                x_tilde[i, t] = xref[]
            end
        end

        x_tilde .= clamp.(x_tilde, 0.0, C)
        u_tilde .= clamp.(u_tilde, 0.0, U)

        return nothing
    end

    return supply_chain_proximal!
end

function solve_supply_chain_management_ocp(; n::Int=20, T::Int=20, numsource::Int=2, numsink::Int=2, dist::Float64=0.4, max_iters::Int=300, rho::Float64=2.5, seed::Int=0)
    phi, A, B, c, x0, C, Ub, idx_source, idx_depart = supply_chain_data(n, T, numsource, numsink, dist; seed=seed)
    prox_operator! = supply_chain_proximal_factory!(C, Ub, idx_source, idx_depart)

    data = OptimalControl_OperatorSplitting.all_data(A, B, c, phi[1], phi[2], phi[3], phi[4], phi[5], x0; rho=rho, alpha=1.8)
    x_opt, u_opt, _ = OptimalControl_OperatorSplitting.solve(data, prox_operator!; max_iters=max_iters)

    return x_opt, u_opt
end

function solve_supply_chain_management_size(size::String; max_iters::Int=300, seed::Int=0)
    n, T, numsource, numsink, dist, rho = supply_chain_size_levels(size)
    return solve_supply_chain_management_ocp(
        n=n,
        T=T,
        numsource=numsource,
        numsink=numsink,
        dist=dist,
        max_iters=max_iters,
        rho=rho,
        seed=seed,
    )
end

println("Benchmarking Supply Chain Management... (Small: n=5, T=20)")
@btime solve_supply_chain_management_size("small")

println("Benchmarking Supply Chain Management... (Medium: n=20, T=20)")
@btime solve_supply_chain_management_size("medium")

println("Benchmarking Supply Chain Management... (Large: n=40, T=20)")
@btime solve_supply_chain_management_size("large")