_stage_matrix(data::AbstractMatrix, _) = data
_stage_matrix(data::AbstractArray{<:Any,3}, stage) = @view data[:, :, stage]

_rhs_top(cache::solver_cache) = reshape(view(cache.rhs, 1:cache.dim_w), cache.data.n + cache.data.m, cache.data.T + 1)
_sol_top(cache::solver_cache) = reshape(view(cache.sol, 1:cache.dim_w), cache.data.n + cache.data.m, cache.data.T + 1)

_stacked_norm(A, B) = hypot(norm(A), norm(B))

function _has_converged(data::all_data, vars::prob_vars, cache::solver_cache)
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

    return r_norm <= eps_pri && s_norm <= eps_dual
end

function _assemble_E(data::all_data)
    blocks = Vector{SparseMatrixCSC{eltype(data),Int}}(undef, data.T + 1)

    for stage in 1:(data.T + 1)
        Q_t = _stage_matrix(data.Q, stage)
        S_t = _stage_matrix(data.S, stage)
        R_t = _stage_matrix(data.R, stage)
        block = [Q_t + data.rho * I(data.n)  S_t;
                 S_t'                        R_t + data.rho * I(data.m)]
        blocks[stage] = sparse(block)
    end

    return blockdiag(blocks...)
end

function _assemble_G(data::all_data)
    dim_lambda = (data.T + 1) * data.n
    dim_w = (data.T + 1) * (data.n + data.m)
    G = spzeros(eltype(data), dim_lambda, dim_w)

    G[1:data.n, 1:data.n] = I(data.n)

    for stage in 1:data.T
        row_start = stage * data.n + 1
        row_end = (stage + 1) * data.n
        col_start_AB = (stage - 1) * (data.n + data.m) + 1
        col_end_AB = stage * (data.n + data.m)
        A_t = _stage_matrix(data.A, stage)
        B_t = _stage_matrix(data.B, stage)

        G[row_start:row_end, col_start_AB:(col_start_AB + data.n - 1)] = -A_t
        G[row_start:row_end, (col_start_AB + data.n):col_end_AB] = -B_t

        col_start_I = stage * (data.n + data.m) + 1
        G[row_start:row_end, col_start_I:(col_start_I + data.n - 1)] = I(data.n)
    end

    return G
end

function solve(data::all_data, prox_operator!; max_iters=3000)
    return solve(setup_cache(data), prox_operator!; max_iters=max_iters)
end

function solve(cache::solver_cache, prox_operator!; max_iters=3000)
    vars = prob_vars(cache.data)
    return solve!(vars, cache, prox_operator!; max_iters=max_iters)
end

function solve!(vars::prob_vars, cache::solver_cache, prox_operator!; max_iters=3000)
    data = cache.data
    rhs_top = _rhs_top(cache)
    sol_top = _sol_top(cache)
    _set_rhs_lower!(cache)

    for _ in 1:max_iters
        copyto!(cache.x_t_prev, vars.x_t)
        copyto!(cache.u_t_prev, vars.u_t)

        for stage in 1:(data.T + 1)
            @views @. rhs_top[1:data.n, stage] = data.rho * (vars.x_t[:, stage] + vars.z[:, stage]) - data.q[:, stage]
            @views @. rhs_top[(data.n + 1):end, stage] = data.rho * (vars.u_t[:, stage] + vars.y[:, stage]) - data.r[:, stage]
        end

        ldiv!(cache.sol, cache.factorization, cache.rhs)

        @views vars.x .= sol_top[1:data.n, :]
        @views vars.u .= sol_top[(data.n + 1):end, :]

        if data.alpha != one(eltype(data))
            vars.x .= data.alpha .* vars.x .+ (one(eltype(data)) - data.alpha) .* vars.x_t
            vars.u .= data.alpha .* vars.u .+ (one(eltype(data)) - data.alpha) .* vars.u_t
        end

        @. cache.v = vars.x - vars.z
        @. cache.w = vars.u - vars.y
        prox_operator!(vars.x_t, vars.u_t, cache.v, cache.w, data.rho)

        vars.z .= vars.z .+ vars.x_t .- vars.x
        vars.y .= vars.y .+ vars.u_t .- vars.u

        if _has_converged(data, vars, cache)
            break
        end
    end

    return vars.x_t, vars.u_t
end
