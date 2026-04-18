using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const RESULTS_DIR = joinpath(ROOT, "report", "article", "results")
const REPORT_PATH = joinpath(ROOT, "report", "c_vs_julia_examples.md")
const EXAMPLES = [
    ("box", "box_constrained_quadratic_optimal_control.jl"),
    ("finance", "multiperiod_portfolio_optimization.jl"),
    ("rob_est", "robust_state_estimation.jl"),
    ("sup_ch", "supply_chain_management.jl"),
]
const SIZES = ["small", "medium", "large"]
const SINGLE_THREAD = true

function parse_stats(output::String)
    cold_iters = parse(Float64, match(r"COLD START:\s*\nIterations ([0-9.]+)", output).captures[1])
    cold_total = parse(Float64, match(r"COLD START:[\s\S]*?Taking \(on average\) ([0-9.]+) ms", output).captures[1])
    cold_lin = parse(Float64, match(r"COLD START:[\s\S]*?Average time to solve linear system: ([0-9.]+) ms", output).captures[1])
    cold_prox = parse(Float64, match(r"COLD START:[\s\S]*?Average time to take prox step: ([0-9.]+) ms", output).captures[1])

    warm_iters = parse(Float64, match(r"Average num iterations ([0-9.]+)", output).captures[1])
    warm_total = parse(Float64, match(r"Taking an average of ([0-9.]+) ms", output).captures[1])
    warm_lin = parse(Float64, match(r"RUNNING [0-9]+ WARM STARTS[\s\S]*?Average time to solve linear system: ([0-9.]+) ms", output).captures[1])
    warm_prox = parse(Float64, match(r"RUNNING [0-9]+ WARM STARTS[\s\S]*?Average time to take prox step: ([0-9.]+) ms", output).captures[1])

    return (
        cold=(iters=cold_iters, total_ms=cold_total, lin_ms=cold_lin, prox_ms=cold_prox),
        warm=(iters=warm_iters, total_ms=warm_total, lin_ms=warm_lin, prox_ms=warm_prox),
    )
end

function run_c(example::String, size::String)
    dir = joinpath(ROOT, "osc", example)
    run_cmd = SINGLE_THREAD ? "OMP_NUM_THREADS=1 ./run_osc" : "./run_osc"
    cmd = `bash -lc $("cp data/$(size)/* data/ && $(run_cmd)")`
    output = cd(dir) do
        read(cmd, String)
    end
    return parse_stats(output)
end

function run_julia(script::String, size::String)
    cmd = `julia --project=. examples/$(script) $(size)`
    if SINGLE_THREAD
        cmd = addenv(cmd, "JULIA_NUM_THREADS" => "1", "OPENBLAS_NUM_THREADS" => "1")
    end
    output = cd(ROOT) do
        read(cmd, String)
    end
    return parse_stats(output)
end

function write_csv(path::String, rows)
    open(path, "w") do io
        println(io, "example,size,c_iters,julia_iters,c_total_ms,julia_total_ms,c_lin_ms,julia_lin_ms,c_prox_ms,julia_prox_ms")
        for row in rows
            println(io,
                row.example, ",",
                row.size, ",",
                @sprintf("%.6f", row.c_iters), ",",
                @sprintf("%.6f", row.julia_iters), ",",
                @sprintf("%.6f", row.c_total_ms), ",",
                @sprintf("%.6f", row.julia_total_ms), ",",
                @sprintf("%.6f", row.c_lin_ms), ",",
                @sprintf("%.6f", row.julia_lin_ms), ",",
                @sprintf("%.6f", row.c_prox_ms), ",",
                @sprintf("%.6f", row.julia_prox_ms),
            )
        end
    end
end

function write_report(path::String)
    open(path, "w") do io
        println(io, "# C vs Julia Comparison")
        println(io)
        println(io, "Comparison outputs are saved as CSV files in `report/article/results/`:")
        println(io)
        println(io, "- `report/article/results/c_vs_julia_cold.csv`")
        println(io, "- `report/article/results/c_vs_julia_warm.csv`")
    end
end

function main()
    mkpath(RESULTS_DIR)

    cold_rows = NamedTuple[]
    warm_rows = NamedTuple[]

    for (example, script) in EXAMPLES
        for size in SIZES
            c = run_c(example, size)
            j = run_julia(script, size)

            push!(cold_rows, (
                example=example,
                size=size,
                c_iters=c.cold.iters,
                julia_iters=j.cold.iters,
                c_total_ms=c.cold.total_ms,
                julia_total_ms=j.cold.total_ms,
                c_lin_ms=c.cold.lin_ms,
                julia_lin_ms=j.cold.lin_ms,
                c_prox_ms=c.cold.prox_ms,
                julia_prox_ms=j.cold.prox_ms,
            ))

            push!(warm_rows, (
                example=example,
                size=size,
                c_iters=c.warm.iters,
                julia_iters=j.warm.iters,
                c_total_ms=c.warm.total_ms,
                julia_total_ms=j.warm.total_ms,
                c_lin_ms=c.warm.lin_ms,
                julia_lin_ms=j.warm.lin_ms,
                c_prox_ms=c.warm.prox_ms,
                julia_prox_ms=j.warm.prox_ms,
            ))
        end
    end

    write_csv(joinpath(RESULTS_DIR, "c_vs_julia_cold.csv"), cold_rows)
    write_csv(joinpath(RESULTS_DIR, "c_vs_julia_warm.csv"), warm_rows)
    write_report(REPORT_PATH)

    println("Wrote: report/article/results/c_vs_julia_cold.csv")
    println("Wrote: report/article/results/c_vs_julia_warm.csv")
    println("Wrote: report/c_vs_julia_examples.md")
end

main()
