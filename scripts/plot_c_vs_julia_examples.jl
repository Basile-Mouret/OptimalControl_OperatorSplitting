ENV["GKSwstype"] = "100"

using Plots
using Plots.PlotMeasures

const ROOT = normpath(joinpath(@__DIR__, ".."))
const REPORT = joinpath(ROOT, "report", "c_vs_julia_examples.md")
const OUT_TIME = joinpath(ROOT, "report", "c_vs_julia_total_time.png")
const OUT_ITERS = joinpath(ROOT, "report", "c_vs_julia_iters.png")

function parse_comparison_table(path::String)
    lines = readlines(path)
    header_idx = findfirst(line -> occursin("| Example |", line), lines)
    header_idx === nothing && error("Could not find table header in $(path)")

    rows = NamedTuple[]
    for line in lines[(header_idx + 2):end]
        line = strip(line)
        isempty(line) && continue
        startswith(line, "|") || continue

        cols = split(line, '|')
        cols = strip.(filter(c -> !isempty(strip(c)), cols))
        length(cols) < 16 && continue

        example = replace(cols[1], "`" => "")
        size = replace(cols[2], "`" => "")
        c_iters = parse(Float64, cols[5])
        j_iters = parse(Float64, cols[6])
        c_total = parse(Float64, cols[8])
        j_total = parse(Float64, cols[9])

        push!(rows, (
            example=example,
            size=size,
            c_iters=c_iters,
            j_iters=j_iters,
            c_total=c_total,
            j_total=j_total,
        ))
    end

    isempty(rows) && error("No data rows parsed from $(path)")
    return rows
end

function _plot_skeleton(; title::String, ylabel::String, xticks)
    return plot(
        title=title,
        xlabel="problem size",
        ylabel=ylabel,
        legend=:topright,
        xticks=xticks,
        left_margin=12mm,
        bottom_margin=12mm,
    )
end

function _series_vectors(rows, example::String, sizes::Vector{String})
    rows_ex = filter(r -> r.example == example, rows)
    size_map = Dict(r.size => r for r in rows_ex)
    have_all = all(s -> haskey(size_map, s), sizes)

    if !have_all
        return nothing
    end

    c_total = [size_map[s].c_total for s in sizes]
    j_total = [size_map[s].j_total for s in sizes]
    c_iters = [size_map[s].c_iters for s in sizes]
    j_iters = [size_map[s].j_iters for s in sizes]
    return (c_total=c_total, j_total=j_total, c_iters=c_iters, j_iters=j_iters)
end

function _add_pair!(plt, xvals, cvals, jvals, example::String, color)
    plot!(
        plt,
        xvals,
        cvals,
        label="$(example) C",
        marker=:circle,
        linestyle=:solid,
        color=color,
    )
    plot!(
        plt,
        xvals,
        jvals,
        label="$(example) Julia",
        marker=:diamond,
        linestyle=:dash,
        color=color,
    )
    return nothing
end

function write_plots(rows)
    sizes = ["small", "medium", "large"]
    xvals = 1:length(sizes)
    xtick_labels = (xvals, sizes)

    examples = unique(row.example for row in rows)
    sort!(examples)

    default(size=(1300, 650), dpi=150)

    colors = palette(:tab10, length(examples))

    p_time = _plot_skeleton(
        title="C vs Julia total time",
        ylabel="time (ms)",
        xticks=xtick_labels,
    )
    p_iters = _plot_skeleton(
        title="C vs Julia iterations",
        ylabel="iterations",
        xticks=xtick_labels,
    )

    for (idx, example) in enumerate(examples)
        series = _series_vectors(rows, example, sizes)
        series === nothing && continue

        _add_pair!(p_time, xvals, series.c_total, series.j_total, example, colors[idx])
        _add_pair!(p_iters, xvals, series.c_iters, series.j_iters, example, colors[idx])
    end

    savefig(p_time, OUT_TIME)
    savefig(p_iters, OUT_ITERS)
end

function main()
    rows = parse_comparison_table(REPORT)
    write_plots(rows)
    println("Wrote: report/c_vs_julia_total_time.png")
    println("Wrote: report/c_vs_julia_iters.png")
end

main()
