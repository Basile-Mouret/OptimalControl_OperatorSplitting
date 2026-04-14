_stage_matrix(data::AbstractMatrix, _) = data
_stage_matrix(data::AbstractArray{<:Any,3}, stage) = @view data[:, :, stage]

_stacked_norm(A, B) = hypot(norm(A), norm(B))

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

function _convergence_metrics!(data::all_data, vars::prob_vars, cache::solver_cache)
    tol_scale = sqrt((data.T + 1) * (data.n + data.m))

    @. cache.v = vars.x_t - vars.x
    @. cache.w = vars.u_t - vars.u
    r_norm = _stacked_norm(cache.v, cache.w)

    @. cache.x_t_prev = vars.x_t - cache.x_t_prev
    @. cache.u_t_prev = vars.u_t - cache.u_t_prev
    s_norm = data.rho * _stacked_norm(cache.x_t_prev, cache.u_t_prev)

    eps_pri = data.eps_abs * tol_scale + data.eps_rel * max(
        _stacked_norm(vars.x, vars.u),
        _stacked_norm(vars.x_t, vars.u_t),
    )
    eps_dual = data.eps_abs * tol_scale + data.eps_rel * _stacked_norm(vars.z, vars.y)

    return r_norm, s_norm, eps_pri, eps_dual
end

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

function solve(data::all_data, prox_operator!; max_iters=3000)
    return solve(setup_cache(data), prox_operator!; max_iters=max_iters)
end

function solve(cache::solver_cache, prox_operator!; max_iters=3000)
    vars = prob_vars(cache.data)
    tt = solve!(vars, cache, prox_operator!; max_iters=max_iters)
    return vars.x_t, vars.u_t, tt
end

function solve!(vars::prob_vars, cache::solver_cache, prox_operator!; max_iters=3000)
    data = cache.data
    tt = Timings{eltype(data)}()
    total_start = time_ns()
    _set_rhs_lower!(cache)

    for iter in 1:max_iters
        copyto!(cache.x_t_prev, vars.x_t)
        copyto!(cache.u_t_prev, vars.u_t)

        for stage in 1:(data.T + 1)
            @views @. cache.rhs_top[1:data.n, stage] = data.rho * (vars.x_t[:, stage] + vars.z[:, stage]) - data.q[:, stage]
            @views @. cache.rhs_top[(data.n + 1):end, stage] = data.rho * (vars.u_t[:, stage] + vars.y[:, stage]) - data.r[:, stage]
        end

        lin_sys_start = time_ns()
        ldiv!(cache.sol, cache.factorization, cache.rhs)
        tt.lin_sys_time += _elapsed_ms(lin_sys_start)

        @views vars.x .= cache.sol_top[1:data.n, :]
        @views vars.u .= cache.sol_top[(data.n + 1):end, :]

        if data.alpha != one(eltype(data))
            vars.x .= data.alpha .* vars.x .+ (one(eltype(data)) - data.alpha) .* vars.x_t
            vars.u .= data.alpha .* vars.u .+ (one(eltype(data)) - data.alpha) .* vars.u_t
        end

        @. cache.v = vars.x - vars.z
        @. cache.w = vars.u - vars.y
        prox_start = time_ns()
        prox_operator!(vars.x_t, vars.u_t, cache.v, cache.w, data.rho)
        tt.prox_time += _elapsed_ms(prox_start)

        vars.z .= vars.z .+ vars.x_t .- vars.x
        vars.y .= vars.y .+ vars.u_t .- vars.u

        tt.itns = iter
        tt.r_norm, tt.s_norm, tt.eps_pri, tt.eps_dual = _convergence_metrics!(data, vars, cache)

        if tt.r_norm <= tt.eps_pri && tt.s_norm <= tt.eps_dual
            tt.converged = true
            break
        end
    end

    if tt.itns > 0
        tt.lin_sys_time /= tt.itns
        tt.prox_time /= tt.itns
    end

    tt.total_time = _elapsed_ms(total_start)
    return tt
end
