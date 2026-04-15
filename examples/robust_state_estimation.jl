using LinearAlgebra
using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

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

function load_fixture(size::String)
    data = load_c_fixture_data("rob_est", size)
    tokens = fixture_tokens("rob_est", size, "data_prox")
    M = parse(Float64, tokens[1])
    prox_operator! = robust_proximal_factory!(M)
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
    println("Running robust state estimation ($size)")
    stats = run(size)
    print_run(stats)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
