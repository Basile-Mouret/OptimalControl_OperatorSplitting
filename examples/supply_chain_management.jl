using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

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

function load_fixture(size::String)
    data = load_c_fixture_data("sup_ch", size)
    tokens = fixture_tokens("sup_ch", size, "data_prox")

    C = parse(Float64, tokens[1])
    U = parse(Float64, tokens[2])
    numsource = parse(Int, tokens[3])
    cursor = 4

    idx_source = parse.(Int, tokens[cursor:(cursor + numsource - 1)]) .+ 1
    cursor += numsource

    idx_depart = Vector{Vector{Int}}(undef, data.n)
    for i in 1:data.n
        len = parse(Int, tokens[cursor])
        cursor += 1
        idx_depart[i] = parse.(Int, tokens[cursor:(cursor + len - 1)]) .+ 1
        cursor += len
    end

    prox_operator! = supply_chain_proximal_factory!(C, U, idx_source, idx_depart)
    return data, prox_operator!
end

function run(size::String; max_iters::Int=3000, num_cold::Int=100, num_warm::Int=100, seed::Int=0)
    data, prox_operator! = load_fixture(size)
    perturb! = uniform_perturbation()
    return run(
        data,
        prox_operator!,
        perturb!;
        max_iters=max_iters,
        num_cold=num_cold,
        num_warm=num_warm,
        seed=seed,
    )
end

function main()
    size = parse_size_arg()
    println("Running supply chain management ($size)")
    stats = run(size)
    print_run(stats)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
