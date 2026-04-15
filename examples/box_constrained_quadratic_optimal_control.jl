using OptimalControl_OperatorSplitting

include(joinpath(@__DIR__, "common.jl"))

function box_proximal_factory!(umin::Float64, umax::Float64)
    function box_proximal!(x_tilde, u_tilde, v, w, rho)
        x_tilde .= v
        u_tilde .= clamp.(w, umin, umax)
    end

    return box_proximal!
end

function load_fixture(size::String)
    data = load_c_fixture_data("box", size)
    tokens = fixture_tokens("box", size, "data_prox")
    umax = parse(Float64, tokens[1])
    umin = parse(Float64, tokens[2])
    prox_operator! = box_proximal_factory!(umin, umax)
    return data, prox_operator!
end

function run(size::String; max_iters=3000, num_cold=100, num_warm=100, seed=0)
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

    println("Running box-constrained quadratic optimal control ($size)")
    stats = run(size)
    print_run(stats)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
