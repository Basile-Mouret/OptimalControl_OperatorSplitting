#=
Shared constructors and internal utilities.

Provides problem/workspace constructors, timing helpers, convergence
metrics, and triplet-based sparse KKT assembly used by cache setup and the
solver.
=#
"""
    all_data(A, B, c, Q, S, R, q, r, x_init; rho=50.0, alpha=1.0, eps_abs=1e-3, eps_rel=1e-3, reg=1e-6)

Construct an [`all_data`](@ref) instance from problem arrays and ADMM settings.

The constructor infers a floating-point scalar type, accepts time-invariant or
stage-varying matrix data, and precomputes problem dimensions.
"""
function all_data(A, B, c, Q, S, R, q, r, x_init; rho=50.0, alpha=1.0, eps_abs=1e-3, eps_rel=1e-3, reg=1e-6)
    Tv = promote_type(eltype(x_init), typeof(float(rho)))
    n = length(x_init)
    m = size(r, 1)
    T = size(c, 2)
    nc = (2 * n + m) * (T + 1)

    return all_data(
        n,
        m,
        T,
        nc,
        Tv(rho),
        Tv(alpha),
        Tv(eps_abs),
        Tv(eps_rel),
        Tv(reg),
        A,
        B,
        c,
        Q,
        S,
        R,
        q,
        r,
        x_init,
    )
end

_stage_matrix(data::AbstractMatrix, _) = data
_stage_matrix(data::AbstractArray{<:Any,3}, stage) = @view data[:, :, stage]

_stacked_norm(A, B) = hypot(norm(A), norm(B))

"""
    prob_vars(data)

Allocate and initialize stacked ADMM variables for `data`.

`x_t` is initialized with `data.x_init` at stage 0 to match the dynamics
constraint layout used by the KKT system.
"""
function prob_vars(data::all_data{Tv}) where {Tv<:AbstractFloat}
    x = zeros(Tv, data.n * (data.T + 1))
    u = zeros(Tv, data.m * (data.T + 1))
    x_t = zeros(Tv, data.n * (data.T + 1))
    u_t = zeros(Tv, data.m * (data.T + 1))
    z = zeros(Tv, data.n * (data.T + 1))
    y = zeros(Tv, data.m * (data.T + 1))

    copyto!(x_t, 1, data.x_init, 1, data.n)
    return prob_vars(x, u, x_t, u_t, z, y)
end

Timings{Tv}() where {Tv<:AbstractFloat} = Timings{Tv}(
    zero(Tv),
    zero(Tv),
    zero(Tv),
    0,
    zero(Tv),
    zero(Tv),
    zero(Tv),
    zero(Tv),
    false,
)

Timings() = Timings{Float64}()

_fmt_ms(x) = string(round(x; digits=3), " ms")
_fmt_ms_per_iter(x) = string(round(x; digits=3), " ms/iter")
_fmt_sci(x) = string(round(x; sigdigits=4))

function Base.show(io::IO, tt::Timings)
    status = tt.converged ? "converged" : "not converged"
    print(io, "Timings(", status, ", ", tt.itns, " itns, ", _fmt_ms(tt.total_time), ")")
end

function Base.show(io::IO, ::MIME"text/plain", tt::Timings)
    status = tt.converged ? "converged" : "not converged"

    println(io, "Timings")
    println(io, "  status: ", status)
    println(io, "  iterations: ", tt.itns)
    println(io, "  total time: ", _fmt_ms(tt.total_time))
    println(io, "  linear solve: ", _fmt_ms_per_iter(tt.lin_sys_time))
    println(io, "  prox: ", _fmt_ms_per_iter(tt.prox_time))
    println(io, "  primal residual: ", _fmt_sci(tt.r_norm), " (tol ", _fmt_sci(tt.eps_pri), ")")
    print(io, "  dual residual: ", _fmt_sci(tt.s_norm), " (tol ", _fmt_sci(tt.eps_dual), ")")
end

_elapsed_ms(start_ns) = (time_ns() - start_ns) / 1e6

function _append_block!(rows, cols, vals, block, row0, col0, scale)
    @inbounds for j in 1:size(block, 2), i in 1:size(block, 1)
        value = scale * block[i, j]
        iszero(value) && continue
        push!(rows, row0 + i - 1)
        push!(cols, col0 + j - 1)
        push!(vals, value)
    end

    return nothing
end

function _append_symmetric_lower!(rows, cols, vals, block, start, diag_shift)
    @inbounds for j in 1:size(block, 2)
        for i in j:size(block, 1)
            value = block[i, j]
            if i == j
                value += diag_shift
            end
            iszero(value) && continue
            push!(rows, start + i - 1)
            push!(cols, start + j - 1)
            push!(vals, value)
        end
    end

    return nothing
end

function _append_transpose_block!(rows, cols, vals, block, row0, col0)
    @inbounds for j in 1:size(block, 1), i in 1:size(block, 2)
        value = block[j, i]
        iszero(value) && continue
        push!(rows, row0 + i - 1)
        push!(cols, col0 + j - 1)
        push!(vals, value)
    end

    return nothing
end

function _append_diagonal_block!(rows, cols, vals, row0, col0, len, value)
    iszero(value) && return nothing

    @inbounds for i in 1:len
        push!(rows, row0 + i - 1)
        push!(cols, col0 + i - 1)
        push!(vals, value)
    end

    return nothing
end

"""
    _convergence_metrics!(data, vars, cache)

Compute primal/dual residuals and stopping tolerances for the current ADMM state.

The formulas follow the residual-based criterion from the paper and the C
reference implementation, using scaled absolute and relative tolerances.
"""
function _convergence_metrics!(data::all_data, vars::prob_vars, cache::solver_cache)
    tol_scale = sqrt((data.T + 1) * (data.n + data.m))

    nx = length(vars.x)
    nu = length(vars.u)

    @inbounds for i in 1:nx
        cache.v[i] = vars.x_t[i] - vars.x[i]
    end
    @inbounds for i in 1:nu
        cache.w[i] = vars.u_t[i] - vars.u[i]
    end
    r_norm = _stacked_norm(cache.v, cache.w)

    @inbounds for i in 1:nx
        cache.x_t_prev[i] = vars.x_t[i] - cache.x_t_prev[i]
    end
    @inbounds for i in 1:nu
        cache.u_t_prev[i] = vars.u_t[i] - cache.u_t_prev[i]
    end
    s_norm = data.rho * _stacked_norm(cache.x_t_prev, cache.u_t_prev)

    eps_pri = data.eps_abs * tol_scale + data.eps_rel * max(
        _stacked_norm(vars.x, vars.u),
        _stacked_norm(vars.x_t, vars.u_t),
    )
    eps_dual = data.eps_abs * tol_scale + data.eps_rel * _stacked_norm(vars.z, vars.y)

    return r_norm, s_norm, eps_pri, eps_dual
end

"""
    _assemble_kkt(data)

Assemble the static symmetric KKT matrix for the linear system step.

The matrix is built once from triplets, stored as lower-triangular symmetric
data, and includes `rho` and `reg` regularization terms.
"""
function _assemble_kkt(data::all_data)
    Tv = eltype(data)
    n = data.n
    m = data.m
    T = data.T
    dim_w = (data.T + 1) * (data.n + data.m)
    dim_lambda = (data.T + 1) * data.n

    stage_nnz_est = div(n * (n + 1), 2) + n * m + div(m * (m + 1), 2) + n + m
    dynamics_nnz_est = n + T * (n * n + n * m + n)
    total_nnz_est = (T + 1) * stage_nnz_est + dynamics_nnz_est + dim_lambda

    rows = Int[]
    cols = Int[]
    vals = Tv[]
    sizehint!(rows, total_nnz_est)
    sizehint!(cols, total_nnz_est)
    sizehint!(vals, total_nnz_est)

    for stage in 1:(T + 1)
        stage_offset = (stage - 1) * (n + m)
        x_start = stage_offset + 1
        u_start = x_start + n

        _append_symmetric_lower!(rows, cols, vals, _stage_matrix(data.Q, stage), x_start, data.rho)
        _append_transpose_block!(rows, cols, vals, _stage_matrix(data.S, stage), u_start, x_start)
        _append_symmetric_lower!(rows, cols, vals, _stage_matrix(data.R, stage), u_start, data.rho)
    end

    for stage in 1:(T + 1)
        row_start = dim_w + (stage - 1) * n + 1

        if stage == 1
            _append_diagonal_block!(rows, cols, vals, row_start, 1, n, one(Tv))
            continue
        end

        prev_stage_offset = (stage - 2) * (n + m)
        cur_x_start = (stage - 1) * (n + m) + 1

        _append_block!(rows, cols, vals, _stage_matrix(data.A, stage - 1), row_start, prev_stage_offset + 1, -one(Tv))
        _append_block!(rows, cols, vals, _stage_matrix(data.B, stage - 1), row_start, prev_stage_offset + n + 1, -one(Tv))
        _append_diagonal_block!(rows, cols, vals, row_start, cur_x_start, n, one(Tv))
    end

    _append_diagonal_block!(rows, cols, vals, dim_w + 1, dim_w + 1, dim_lambda, -data.reg)

    return Symmetric(sparse(rows, cols, vals, data.nc, data.nc), :L)
end
