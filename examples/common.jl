using SparseArrays

function parse_size_arg(; default="small")
    size = isempty(ARGS) ? default : lowercase(ARGS[1])

    if size != "small" && size != "medium" && size != "large"
        error("Invalid size `$size`. Choose from `small`, `medium`, or `large`.")
    end

    return size
end

fixture_path(example::String, size::String, name::String) =
    joinpath(@__DIR__, "..", "osc", example, "data", size, name)

fixture_tokens(example::String, size::String, name::String) =
    split(read(fixture_path(example, size, name), String))

function load_c_fixture_data(example::String, size::String; eps_abs=1e-3, eps_rel=1e-3)
    open(fixture_path(example, size, "data_KKT"), "r") do io
        header = split(readline(io))
        n = parse(Int, header[1])
        m = parse(Int, header[2])
        T = parse(Int, header[3])
        nnz = parse(Int, header[4])
        rho = parse(Float64, header[5])
        alpha = parse(Float64, header[6])

        x_init = parse.(Float64, split(readline(io)))
        Ar = parse.(Int, split(readline(io))) .+ 1
        Ap = parse.(Int, split(readline(io))) .+ 1
        Ax = parse.(Float64, split(readline(io)))
        rhs = parse.(Float64, split(readline(io)))

        nc = length(rhs)
        @assert length(Ar) == nnz
        @assert length(Ax) == nnz
        @assert length(Ap) == nc + 1

        KKT = SparseMatrixCSC{Float64, Int}(nc, nc, Ap, Ar, Ax)

        dim_w = (T + 1) * (n + m)
        dim_lambda = (T + 1) * n

        top = -reshape(rhs[1:dim_w], n + m, T + 1)
        q = copy(top[1:n, :])
        r = copy(top[(n + 1):end, :])

        lower = rhs[(dim_w + 1):end]
        x_init_rhs = copy(lower[1:n])
        c = reshape(copy(lower[(n + 1):end]), n, T)

        Q = zeros(Float64, n, n, T + 1)
        S = zeros(Float64, n, m, T + 1)
        R = zeros(Float64, m, m, T + 1)
        A = zeros(Float64, n, n, T)
        B = zeros(Float64, n, m, T)

        for stage in 1:(T + 1)
            start = (stage - 1) * (n + m) + 1
            stop = stage * (n + m)
            E_t = Matrix(KKT[start:stop, start:stop])

            Q[:, :, stage] .= E_t[1:n, 1:n]
            S[:, :, stage] .= E_t[1:n, (n + 1):end]
            R[:, :, stage] .= E_t[(n + 1):end, (n + 1):end]

            @inbounds for i in 1:n
                Q[i, i, stage] -= rho
            end
            @inbounds for i in 1:m
                R[i, i, stage] -= rho
            end
        end

        for stage in 1:T
            row_start = dim_w + stage * n + 1
            row_stop = dim_w + (stage + 1) * n
            col_start = (stage - 1) * (n + m) + 1
            col_stop = stage * (n + m)
            G_t = Matrix(KKT[row_start:row_stop, col_start:col_stop])

            A[:, :, stage] .= -G_t[:, 1:n]
            B[:, :, stage] .= -G_t[:, (n + 1):end]
        end

        reg = -KKT[dim_w + 1, dim_w + 1]

        return all_data(
            A,
            B,
            c,
            Q,
            S,
            R,
            q,
            r,
            x_init_rhs;
            rho=rho,
            alpha=alpha,
            eps_abs=eps_abs,
            eps_rel=eps_rel,
            reg=reg,
        )
    end
end
