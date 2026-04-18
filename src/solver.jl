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

# Arguments
- `cache`: object returned by [`setup_cache`](@ref)
- `prox_operator!`: in-place proximal update with signature
  `prox_operator!(x_tilde, u_tilde, v, w, rho)`
- `max_iters`: maximum ADMM iterations

# Returns
- `(x, u, tt)` where `x` and `u` are stage-wise trajectories and `tt::Timings`

The solve loop uses cached factorizations and in-place updates throughout.
It returns copies of the current trajectories together with timing and
convergence information.
"""
function solve(cache::solver_cache, prox_operator!; max_iters=3000)
    data = cache.data
    vars = cache.vars
    T1 = data.T + 1
    n = data.n
    m = data.m
    nm = n + m
    nx = n * T1
    nu = m * T1
    rhs_top = view(cache.rhs, 1:(nm * T1))
    sol_top = view(cache.sol, 1:(nm * T1))
    v_view = reshape(cache.v, n, T1)
    w_view = reshape(cache.w, m, T1)
    x_t_view = reshape(vars.x_t, n, T1)
    u_t_view = reshape(vars.u_t, m, T1)
    tt = Timings{eltype(data)}()
    total_start = time_ns()
    _set_rhs_lower!(cache)

    for iter in 1:max_iters
        copyto!(cache.x_t_prev, vars.x_t)
        copyto!(cache.u_t_prev, vars.u_t)

        @inbounds for stage in 1:T1
            base_rhs = (stage - 1) * nm
            base_x = (stage - 1) * n
            base_u = (stage - 1) * m

            for i in 1:n
                rhs_top[base_rhs + i] = data.rho * (vars.x_t[base_x + i] + vars.z[base_x + i]) - data.q[i, stage]
            end
            for i in 1:m
                rhs_top[base_rhs + n + i] = data.rho * (vars.u_t[base_u + i] + vars.y[base_u + i]) - data.r[i, stage]
            end
        end

        lin_sys_start = time_ns()
        ldiv!(cache.sol, cache.factorization, cache.rhs)
        tt.lin_sys_time += _elapsed_ms(lin_sys_start)

        @inbounds for stage in 1:T1
            base_rhs = (stage - 1) * nm
            base_x = (stage - 1) * n
            base_u = (stage - 1) * m

            for i in 1:n
                vars.x[base_x + i] = sol_top[base_rhs + i]
            end
            for i in 1:m
                vars.u[base_u + i] = sol_top[base_rhs + n + i]
            end
        end

        if data.alpha != one(eltype(data))
            omalpha = one(eltype(data)) - data.alpha
            @inbounds for i in 1:nx
                vars.x[i] = data.alpha * vars.x[i] + omalpha * vars.x_t[i]
            end
            @inbounds for i in 1:nu
                vars.u[i] = data.alpha * vars.u[i] + omalpha * vars.u_t[i]
            end
        end

        @inbounds for i in 1:nx
            cache.v[i] = vars.x[i] - vars.z[i]
        end
        @inbounds for i in 1:nu
            cache.w[i] = vars.u[i] - vars.y[i]
        end

        prox_start = time_ns()
        prox_operator!(x_t_view, u_t_view, v_view, w_view, data.rho)
        tt.prox_time += _elapsed_ms(prox_start)

        @inbounds for i in 1:nx
            vars.z[i] += vars.x_t[i] - vars.x[i]
        end
        @inbounds for i in 1:nu
            vars.y[i] += vars.u_t[i] - vars.u[i]
        end

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
    return copy(reshape(vars.x_t, n, T1)), copy(reshape(vars.u_t, m, T1)), tt
end
