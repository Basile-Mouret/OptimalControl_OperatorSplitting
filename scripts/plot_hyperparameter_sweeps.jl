ENV["GKSwstype"] = "100"

using OptimalControl_OperatorSplitting
using LinearAlgebra
using Plots
using Plots.PlotMeasures
using Random

include(joinpath(@__DIR__, "..", "examples", "common.jl"))
include(joinpath(@__DIR__, "..", "examples", "box_constrained_quadratic_optimal_control.jl"))

const ROOT = normpath(joinpath(@__DIR__, ".."))
const FIGURES_DIR = joinpath(ROOT, "report", "article", "figures")

function problem_dimensions(size::String)
    if size == "small"
        return 4, 2, 20
    elseif size == "medium"
        return 8, 3, 30
    elseif size == "large"
        return 12, 4, 40
    else
        error("Invalid size `$size`. Choose from `small`, `medium`, or `large`.")
    end
end

function make_identity_stages(n::Int, m::Int, T::Int)
    Q = zeros(Float64, n, n, T + 1)
    R = zeros(Float64, m, m, T + 1)
    S = zeros(Float64, n, m, T + 1)

    for stage in 1:(T + 1)
        @inbounds for i in 1:n
            Q[i, i, stage] = 1.0
        end
        @inbounds for i in 1:m
            R[i, i, stage] = 0.2
        end
    end

    return Q, S, R
end

function rebuild_data(base::all_data; rho=base.rho, alpha=base.alpha, eps_abs=base.eps_abs, eps_rel=base.eps_rel, reg=base.reg)
    return all_data(
        base.A,
        base.B,
        base.c,
        base.Q,
        base.S,
        base.R,
        base.q,
        base.r,
        copy(base.x_init);
        rho=rho,
        alpha=alpha,
        eps_abs=eps_abs,
        eps_rel=eps_rel,
        reg=reg,
    )
end

function solve_iters(data::all_data, prox_operator!; max_iters::Int=5000)
    cache = setup_cache(data)
    _, _, tt = solve(cache, prox_operator!; max_iters=max_iters)
    return tt.itns, tt.converged
end

function sweep_values(base::all_data, prox_operator!, param::Symbol, values; max_iters::Int=5000)
    iterations = Float64[]
    converged = Bool[]

    for value in values
        data = if param == :rho
            rebuild_data(base; rho=value)
        elseif param == :alpha
            rebuild_data(base; alpha=value)
        elseif param == :eps_abs
            rebuild_data(base; eps_abs=value)
        elseif param == :eps_rel
            rebuild_data(base; eps_rel=value)
        elseif param == :reg
            rebuild_data(base; reg=value)
        else
            error("Unsupported parameter: $(param)")
        end

        itns, ok = solve_iters(data, prox_operator!; max_iters=max_iters)
        push!(iterations, Float64(itns))
        push!(converged, ok)
    end

    return iterations, converged
end

function make_plot(values, iterations; title::String, xlabel::String, outname::String, xscale=:identity)
    plt = plot(
        values,
        iterations;
        marker=:circle,
        linewidth=2,
        color="#1F3A93",
        markercolor="#1F3A93",
        markerstrokecolor="#1F3A93",
        legend=false,
        title=title,
        xlabel=xlabel,
        ylabel="iterations",
        xscale=xscale,
        background_color=:white,
        foreground_color=:black,
        left_margin=12mm,
        bottom_margin=12mm,
        size=(900, 560),
        dpi=160,
    )

    outpath = joinpath(FIGURES_DIR, outname)
    savefig(plt, outpath)
    println("Wrote: report/article/figures/", outname)
    return nothing
end

function main()
    size = parse_size_arg()
    mkpath(FIGURES_DIR)

    try
        base_data, prox_operator! = load_fixture(size)

        sweeps = [
            (
                param=:rho,
                values=10.0 .^ range(0.0, stop=3.0, length=7),
                title="Iterations vs rho",
                xlabel="rho",
                outname="iterations_vs_rho.png",
                xscale=:log10,
            ),
            (
                param=:alpha,
                values=collect(range(0.5, stop=1.95, length=10)),
                title="Iterations vs alpha",
                xlabel="alpha",
                outname="iterations_vs_alpha.png",
                xscale=:identity,
            ),
            (
                param=:eps_abs,
                values=10.0 .^ range(-6.0, stop=-1.0, length=6),
                title="Iterations vs eps_abs",
                xlabel="eps_abs",
                outname="iterations_vs_eps_abs.png",
                xscale=:log10,
            ),
            (
                param=:eps_rel,
                values=10.0 .^ range(-6.0, stop=-1.0, length=6),
                title="Iterations vs eps_rel",
                xlabel="eps_rel",
                outname="iterations_vs_eps_rel.png",
                xscale=:log10,
            ),
            (
                param=:reg,
                values=10.0 .^ range(-8.0, stop=-3.0, length=6),
                title="Iterations vs reg",
                xlabel="reg",
                outname="iterations_vs_reg.png",
                xscale=:log10,
            ),
        ]

        println("Running hyperparameter sweeps for box-constrained quadratic optimal control ($size)")
        println("Outputs will be written to report/article/figures/")

        for sweep in sweeps
            iterations, converged = sweep_values(base_data, prox_operator!, sweep.param, sweep.values)
            if any(!, converged)
                println("Warning: some points did not converge for ", sweep.param)
            end
            make_plot(
                sweep.values,
                iterations;
                title=sweep.title,
                xlabel=sweep.xlabel,
                outname=sweep.outname,
                xscale=sweep.xscale,
            )
        end
    catch err
        if err isa SystemError || err isa IOError
            error("The box example fixtures are missing. This script expects the external osc data under examples/../osc/box/data/<size>/.")
        end
        rethrow(err)
    end
end

main()