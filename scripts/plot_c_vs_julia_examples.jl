ENV["GKSwstype"] = "100"

using DelimitedFiles
using Plots
using Plots.PlotMeasures

const ROOT = normpath(joinpath(@__DIR__, ".."))
const RESULTS_DIR = joinpath(ROOT, "results")
const FIGURES_DIR = joinpath(ROOT, "report", "article", "figures")
const COLD_CSV = joinpath(RESULTS_DIR, "c_vs_julia_cold.csv")
const WARM_CSV = joinpath(RESULTS_DIR, "c_vs_julia_warm.csv")

function read_csv_rows(path::String)
    raw = readdlm(path, ','; header=true)
    data = raw[1]
    rows = NamedTuple[]

    tostr(x) = x isa AbstractString ? String(x) : string(x)

    for i in 1:size(data, 1)
        push!(rows, (
            example=tostr(data[i, 1]),
            size=tostr(data[i, 2]),
            c_iters=parse(Float64, tostr(data[i, 3])),
            julia_iters=parse(Float64, tostr(data[i, 4])),
            c_total_ms=parse(Float64, tostr(data[i, 5])),
            julia_total_ms=parse(Float64, tostr(data[i, 6])),
            c_lin_ms=parse(Float64, tostr(data[i, 7])),
            julia_lin_ms=parse(Float64, tostr(data[i, 8])),
            c_prox_ms=parse(Float64, tostr(data[i, 9])),
            julia_prox_ms=parse(Float64, tostr(data[i, 10])),
        ))
    end

    return rows
end

function _plot_skeleton(; title::String, ylabel::String, xticks, yscale=:identity)
    return plot(
        title=title,
        xlabel="problem size",
        ylabel=ylabel,
        legend=:bottomright,
        background_color_legend=:white,
        foreground_color_legend=:black,
        xticks=xticks,
        yscale=yscale,
        left_margin=12mm,
        bottom_margin=12mm,
    )
end

function _series(rows, example::String, sizes::Vector{String}, cfield::Symbol, jfield::Symbol)
    rows_ex = filter(r -> r.example == example, rows)
    size_map = Dict(r.size => r for r in rows_ex)
    all(s -> haskey(size_map, s), sizes) || return nothing

    cvals = [getfield(size_map[s], cfield) for s in sizes]
    jvals = [getfield(size_map[s], jfield) for s in sizes]
    return (c=cvals, j=jvals)
end

function _add_pair!(plt, xvals, cvals, jvals, example::String, color)
    plot!(plt, xvals, cvals; label="$(example) C", marker=:circle, linestyle=:solid, color=color)
    plot!(plt, xvals, jvals; label="$(example) Julia", marker=:diamond, linestyle=:dash, color=color)
    return nothing
end

function write_one_plot(rows, cfield::Symbol, jfield::Symbol, title::String, ylabel::String, outname::String; logy::Bool=false)
    sizes = ["small", "medium", "large"]
    xvals = 1:length(sizes)
    xticks = (xvals, sizes)
    examples = sort(unique(row.example for row in rows))
    colors = palette(:tab10, length(examples))

    plt = _plot_skeleton(title=title, ylabel=ylabel, xticks=xticks, yscale=(logy ? :log10 : :identity))
    for (idx, example) in enumerate(examples)
        s = _series(rows, example, sizes, cfield, jfield)
        s === nothing && continue
        cvals = logy ? max.(s.c, 1e-6) : s.c
        jvals = logy ? max.(s.j, 1e-6) : s.j
        _add_pair!(plt, xvals, cvals, jvals, example, colors[idx])
    end

    outpath = joinpath(FIGURES_DIR, outname)
    savefig(plt, outpath)
    println("Wrote: report/article/figures/", outname)
end

function main()
    mkpath(FIGURES_DIR)

    cold_rows = read_csv_rows(COLD_CSV)
    warm_rows = read_csv_rows(WARM_CSV)

    default(size=(1300, 650), dpi=150)

    write_one_plot(cold_rows, :c_total_ms, :julia_total_ms, "Cold: total time", "time (ms)", "c_vs_julia_cold_total.png"; logy=true)
    write_one_plot(warm_rows, :c_total_ms, :julia_total_ms, "Warm: total time", "time (ms)", "c_vs_julia_warm_total.png"; logy=true)

    write_one_plot(cold_rows, :c_lin_ms, :julia_lin_ms, "Cold: linear solve time", "ms/iter", "c_vs_julia_cold_lin.png"; logy=true)
    write_one_plot(warm_rows, :c_lin_ms, :julia_lin_ms, "Warm: linear solve time", "ms/iter", "c_vs_julia_warm_lin.png"; logy=true)

    write_one_plot(cold_rows, :c_prox_ms, :julia_prox_ms, "Cold: prox time", "ms/iter", "c_vs_julia_cold_prox.png"; logy=true)
    write_one_plot(warm_rows, :c_prox_ms, :julia_prox_ms, "Warm: prox time", "ms/iter", "c_vs_julia_warm_prox.png"; logy=true)
end

main()
