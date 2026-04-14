using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXAMPLES = [
    ("box", "box_constrained_quadratic_optimal_control.jl", "load_box_fixture"),
    ("finance", "multiperiod_portfolio_optimization.jl", "load_multiperiod_portfolio_fixture"),
    ("rob_est", "robust_state_estimation.jl", "load_robust_state_estimation_fixture"),
    ("sup_ch", "supply_chain_management.jl", "load_supply_chain_fixture"),
]
const SIZES = ["small", "medium", "large"]
const N_COLD = 100
const SINGLE_THREAD = true

function parse_c_stats(output::String)
    factor = parse(Float64, match(r"KKT matrix factorization took ([0-9.]+) ms", output).captures[1])
    iters = parse(Float64, match(r"COLD START:\s*\nIterations ([0-9.]+)", output).captures[1])
    total = parse(Float64, match(r"Taking \(on average\) ([0-9.]+) ms", output).captures[1])
    lin = parse(Float64, match(r"Average time to solve linear system: ([0-9.]+) ms", output).captures[1])
    prox = parse(Float64, match(r"Average time to take prox step: ([0-9.]+) ms", output).captures[1])
    return (factor=factor, iters=iters, total=total, lin=lin, prox=prox)
end

function parse_julia_stats(output::String)
    setup = parse(Float64, match(r"setup=([0-9.eE+-]+)", output).captures[1])
    iters = parse(Float64, match(r"iters=([0-9.eE+-]+)", output).captures[1])
    total = parse(Float64, match(r"total=([0-9.eE+-]+)", output).captures[1])
    lin = parse(Float64, match(r"lin=([0-9.eE+-]+)", output).captures[1])
    prox = parse(Float64, match(r"prox=([0-9.eE+-]+)", output).captures[1])
    converged = match(r"converged=(true|false)", output).captures[1] == "true"
    return (setup=setup, iters=iters, total=total, lin=lin, prox=prox, converged=converged)
end

function run_c(example::String, size::String)
    dir = joinpath(ROOT, "osc", example)
    run_cmd = SINGLE_THREAD ? "OMP_NUM_THREADS=1 ./run_osc" : "./run_osc"
    cmd = `bash -lc $("cp data/$(size)/* data/ && $(run_cmd)")`
    output = cd(dir) do
        read(cmd, String)
    end
    return parse_c_stats(output)
end

function julia_benchmark_code(script::String, loader::String, size::String)
    return """
    using LinearAlgebra
    using OptimalControl_OperatorSplitting
    include(joinpath(pwd(), \"examples\", \"$script\"))

    BLAS.set_num_threads(1)

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

    function main()
        data, prox_operator! = $loader(\"$size\")

        warm_cache = setup_cache(data)
        reset_cache!(warm_cache)
        solve(warm_cache, prox_operator!; max_iters=1)

        setup_start = time_ns()
        cache = setup_cache(data)
        setup_ms = (time_ns() - setup_start) / 1e6

        iters = 0.0
        total = 0.0
        lin = 0.0
        prox = 0.0
        converged = true

        for _ in 1:$N_COLD
            reset_cache!(cache)
            _, _, tt = solve(cache, prox_operator!; max_iters=3000)
            iters += tt.itns / $N_COLD
            total += tt.total_time / $N_COLD
            lin += tt.lin_sys_time / $N_COLD
            prox += tt.prox_time / $N_COLD
            converged &= tt.converged
        end

        println(\"setup=\", setup_ms,
                \" iters=\", iters,
                \" total=\", total,
                \" lin=\", lin,
                \" prox=\", prox,
                \" converged=\", converged)
    end

    main()
    """
end

function run_julia(script::String, loader::String, size::String)
    if SINGLE_THREAD
        cmd = `julia --project=. -e $(julia_benchmark_code(script, loader, size))`
        cmd = addenv(cmd, "JULIA_NUM_THREADS" => "1")
    else
        cmd = `julia --project=. -e $(julia_benchmark_code(script, loader, size))`
    end
    output = cd(ROOT) do
        read(cmd, String)
    end
    return parse_julia_stats(output)
end

function fmt(x)
    return @sprintf("%.3f", x)
end

function main()
    rows = NamedTuple[]

    for (example, script, loader) in EXAMPLES
        for size in SIZES
            c = run_c(example, size)
            j = run_julia(script, loader, size)
            push!(rows, (
                example=example,
                size=size,
                c_factor=c.factor,
                j_setup=j.setup,
                c_iters=c.iters,
                j_iters=j.iters,
                c_total=c.total,
                j_total=j.total,
                c_lin=c.lin,
                j_lin=j.lin,
                c_prox=c.prox,
                j_prox=j.prox,
                j_converged=j.converged,
            ))
        end
    end

    io = IOBuffer()
    println(io, "# C vs Julia Example Comparison")
    println(io)
    println(io, "Cold-start comparison on the exact `osc/<example>/data/<size>/` fixtures.")
    println(io)
    println(io, "Notes:")
    println(io, "- C numbers come from `run_osc` and are the reported average over 100 cold starts.")
    println(io, "- Julia numbers are warmed first, then averaged over 100 cold starts on the same fixture data, with the cache state reset between solves.")
    println(io, "- Both sides are run in single-thread mode (`OMP_NUM_THREADS=1`, `JULIA_NUM_THREADS=1`, `BLAS.set_num_threads(1)`).")
    println(io, "- `C factor ms` is the factorization time reported by the C code.")
    println(io, "- `Julia setup ms` is one warmed `setup_cache(data)` call and therefore includes Julia-side KKT assembly plus factorization.")
    println(io)
    println(io, "| Example | Size | C factor ms | Julia setup ms | C iters | Julia iters | Δ iters | C total ms | Julia total ms | Δ total ms | Julia/C total | C lin ms/iter | Julia lin ms/iter | C prox ms/iter | Julia prox ms/iter | Julia converged |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")

    for row in rows
        delta_iters = row.j_iters - row.c_iters
        delta_total = row.j_total - row.c_total
        ratio_total = row.j_total / row.c_total
        println(io,
            "| `", row.example, "` | `", row.size, "` | ",
            fmt(row.c_factor), " | ", fmt(row.j_setup), " | ",
            fmt(row.c_iters), " | ", fmt(row.j_iters), " | ", fmt(delta_iters), " | ",
            fmt(row.c_total), " | ", fmt(row.j_total), " | ", fmt(delta_total), " | ", fmt(ratio_total), " | ",
            fmt(row.c_lin), " | ", fmt(row.j_lin), " | ",
            fmt(row.c_prox), " | ", fmt(row.j_prox), " | ", row.j_converged, " |"
        )
    end

    write(joinpath(ROOT, "report", "c_vs_julia_examples.md"), String(take!(io)))
end

main()
