#=
Solver API and ADMM loop.

Implements the cached solve path on top of the shared cache, including
residual-based stopping and timing collection.
=#
"""
    solve(cache, prox_operator!; max_iters=3000)

Solve using a prebuilt cache. A fresh cache gives a cold start; repeated calls
on the same cache reuse the internal ADMM state and therefore warm start.
Returns copies of the current trajectories together with the timing data.
"""
function solve(cache::solver_cache, prox_operator!; max_iters=3000)
    data = cache.data
    vars = cache.vars
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
    return copy(vars.x_t), copy(vars.u_t), tt
end
