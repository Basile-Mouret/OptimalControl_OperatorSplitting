using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

@inline pos(x::Float64) = x > 0.0 ? x : 0.0

@inline function soft_thresh(x::Float64, gamma::Float64)
    ax = abs(x)
    return ax == 0.0 ? 0.0 : x * pos(1.0 - gamma / ax)
end

function portfolio_proximal_factory!(kappa::Vector{Float64}, x_term::Vector{Float64})
    function portfolio_proximal!(x_tilde, u_tilde, v, w, rho)
        n, num_steps = size(v)
        T = num_steps - 1

        for t in 1:T
            @inbounds for j in 1:n
                temp = soft_thresh(w[j, t], kappa[j] / rho)
                if v[j, t] + temp >= 0.0
                    x_tilde[j, t] = v[j, t]
                    u_tilde[j, t] = temp
                else
                    ut2 = soft_thresh((w[j, t] - v[j, t]) / 2.0, kappa[j] / (2.0 * rho))
                    u_tilde[j, t] = ut2
                    x_tilde[j, t] = -ut2
                end
            end
        end

        t = T + 1
        @inbounds for j in 1:n
            ut = soft_thresh((w[j, t] - v[j, t] + x_term[j]) / 2.0, kappa[j] / (2.0 * rho))
            u_tilde[j, t] = ut
            x_tilde[j, t] = x_term[j] - ut
        end

        return nothing
    end

    return portfolio_proximal!
end

function load_fixture(size::String)
    data = load_c_fixture_data("finance", size)
    tokens = fixture_tokens("finance", size, "data_prox")
    n = data.n
    kappa = parse.(Float64, tokens[1:n])
    x_term = parse.(Float64, tokens[(n + 1):(2 * n)])
    prox_operator! = portfolio_proximal_factory!(kappa, x_term)
    return data, prox_operator!
end

function run(size::String; max_iters::Int=3000, num_cold::Int=100, num_warm::Int=100, seed::Int=0)
    data, prox_operator! = load_fixture(size)
    perturb! = gaussian_perturbation()
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
    println("Running multiperiod portfolio optimization ($size)")
    stats = run(size)
    print_run(stats)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
