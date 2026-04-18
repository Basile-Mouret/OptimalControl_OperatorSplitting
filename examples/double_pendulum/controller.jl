using ForwardDiff
using LinearAlgebra
using OptimalControl_OperatorSplitting

struct MPCConfig
    horizon::Int
    dt::Float64
    max_force::Float64
    max_iters::Int
    rho::Float64
    eps_abs::Float64
    eps_rel::Float64
    stage_state_weight::Matrix{Float64}
    terminal_state_weight::Matrix{Float64}
    stage_input_weight::Matrix{Float64}
    capture_enter_angle::Float64
    capture_enter_rate::Float64
    capture_exit_angle::Float64
    capture_exit_rate::Float64
end

function default_mpc_config()
    q_stage = Diagonal([4.0, 1.5, 110.0, 18.0, 78.0, 13.0])
    q_terminal = Diagonal([18.0, 6.0, 420.0, 38.0, 300.0, 28.0])
    r_stage = Diagonal([0.05])

    return MPCConfig(
        24,
        0.03,
        22.0,
        110,
        24.0,
        1e-3,
        1e-3,
        Matrix(q_stage),
        Matrix(q_terminal),
        Matrix(r_stage),
        0.18,
        0.8,
        0.4,
        1.8,
    )
end

mutable struct HybridController{Tc,Tp}
    params::CartDoublePendulumParams
    config::MPCConfig
    feedback_gain::Matrix{Float64}
    cache::Tc
    prox_operator!::Tp
    mode::Symbol
    last_force::Float64
    last_solver_ms::Float64
    last_iterations::Int
    last_converged::Bool
    last_energy_error::Float64
end

function linearize_dynamics(params::CartDoublePendulumParams, state_nominal::AbstractVector, force_nominal, dt)
    state_map = state -> rk4_step(params, state, force_nominal, dt)
    input_map = input -> rk4_step(params, state_nominal, input[1], dt)

    a_matrix = ForwardDiff.jacobian(state_map, state_nominal)
    b_matrix = ForwardDiff.jacobian(input_map, [force_nominal])
    nominal_next = state_map(state_nominal)
    affine_term = nominal_next - a_matrix * state_nominal - b_matrix * [force_nominal]
    return a_matrix, b_matrix, affine_term
end

function local_lqr_gain(a_matrix::AbstractMatrix, b_matrix::AbstractMatrix, q_matrix::AbstractMatrix, r_matrix::AbstractMatrix; max_iters=500, tol=1e-9)
    p_matrix = Matrix(q_matrix)

    for _ in 1:max_iters
        gain_denom = r_matrix + b_matrix' * p_matrix * b_matrix
        gain_num = b_matrix' * p_matrix * a_matrix
        gain = gain_denom \ gain_num
        next_p = q_matrix + a_matrix' * p_matrix * (a_matrix - b_matrix * gain)
        next_p = 0.5 .* (next_p .+ next_p')

        if norm(next_p - p_matrix) <= tol
            p_matrix = next_p
            break
        end

        p_matrix .= next_p
    end

    return (r_matrix + b_matrix' * p_matrix * b_matrix) \ (b_matrix' * p_matrix * a_matrix)
end

function build_mpc_cache(a_matrix::AbstractMatrix, b_matrix::AbstractMatrix, affine_term::AbstractVector, config::MPCConfig)
    n = size(a_matrix, 1)
    horizon = config.horizon

    q_matrix = zeros(n, n, horizon + 1)
    for stage in 1:horizon
        q_matrix[:, :, stage] .= config.stage_state_weight
    end
    q_matrix[:, :, end] .= config.terminal_state_weight

    data = all_data(
        a_matrix,
        b_matrix,
        repeat(reshape(affine_term, :, 1), 1, horizon),
        q_matrix,
        zeros(n, 1),
        config.stage_input_weight,
        zeros(n, horizon + 1),
        zeros(1, horizon + 1),
        zeros(n);
        rho=config.rho,
        alpha=1.0,
        eps_abs=config.eps_abs,
        eps_rel=config.eps_rel,
    )

    return setup_cache(data)
end

function build_hybrid_controller(params::CartDoublePendulumParams; config=default_mpc_config())
    a_matrix, b_matrix, affine_term = linearize_dynamics(params, zeros(6), 0.0, config.dt)
    feedback_gain = local_lqr_gain(a_matrix, b_matrix, config.terminal_state_weight, config.stage_input_weight)
    cache = build_mpc_cache(a_matrix, b_matrix, affine_term, config)
    prox_operator! = let max_force = config.max_force
        function (x_tilde, u_tilde, v, w, rho)
            x_tilde .= v
            u_tilde .= clamp.(w, -max_force, max_force)
            return nothing
        end
    end

    return HybridController(
        params,
        config,
        Matrix(feedback_gain),
        cache,
        prox_operator!,
        :swing_up,
        0.0,
        0.0,
        0,
        false,
        0.0,
    )
end

function in_capture_region(controller::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle <= controller.config.capture_enter_angle &&
        error.rate <= controller.config.capture_enter_rate
end

function in_capture_band(::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle <= 1.0 && error.rate <= 5.0
end

function outside_balance_region(controller::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle >= controller.config.capture_exit_angle ||
        error.rate >= controller.config.capture_exit_rate
end

function reset_cache!(cache)
    vars = cache.vars
    fill!(vars.x, 0.0)
    fill!(vars.u, 0.0)
    fill!(vars.x_t, 0.0)
    fill!(vars.u_t, 0.0)
    fill!(vars.z, 0.0)
    fill!(vars.y, 0.0)
    fill!(cache.data.x_init, 0.0)
    return nothing
end

function clear_solver_status!(controller::HybridController)
    controller.last_solver_ms = 0.0
    controller.last_iterations = 0
    controller.last_converged = false
    return nothing
end

function fallback_balance_force(controller::HybridController, state::AbstractVector)
    local_state = copy(state)
    local_state[3] = wrap_angle(local_state[3])
    local_state[5] = wrap_angle(local_state[5])
    force = -(controller.feedback_gain * local_state)[1]
    return clamp(force, -controller.config.max_force, controller.config.max_force)
end

function swing_up_force(controller::HybridController, state::AbstractVector)
    energy_gain = 0.22
    shape_gain = 11.0
    cart_gain = 4.0
    cart_rate_gain = 3.2

    theta1 = wrap_angle(state[3])
    theta2 = wrap_angle(state[5])
    energy_error = target_energy(controller.params) - total_energy(controller.params, state)
    phase = state[4] * cos(theta1) + 0.65 * state[6] * cos(theta2)
    shape = sin(theta1) + 0.7 * sin(theta2)

    force = energy_gain * energy_error * phase -
        shape_gain * shape -
        cart_gain * state[1] -
        cart_rate_gain * state[2]

    controller.last_energy_error = energy_error
    return clamp(force, -controller.config.max_force, controller.config.max_force)
end

function stabilize_force!(controller::HybridController, state::AbstractVector)
    cache = controller.cache
    cache.data.x_init .= state
    copyto!(cache.vars.x, 1, state, 1, cache.data.n)
    copyto!(cache.vars.x_t, 1, state, 1, cache.data.n)

    controller.last_energy_error = target_energy(controller.params) - total_energy(controller.params, state)
    fallback_force = fallback_balance_force(controller, state)
    _, controls, timings = solve(cache, controller.prox_operator!; max_iters=controller.config.max_iters)

    controller.last_solver_ms = timings.total_time
    controller.last_iterations = timings.itns
    controller.last_converged = timings.converged

    command = controls[1, 1]
    if !isfinite(command)
        command = fallback_force
    elseif timings.converged
        command = 0.4 * command + 0.6 * fallback_force
    else
        command = fallback_force
    end

    return clamp(command, -controller.config.max_force, controller.config.max_force)
end

function update_mode!(controller::HybridController, state::AbstractVector)
    if controller.mode == :stabilize && outside_balance_region(controller, state)
        controller.mode = in_capture_band(controller, state) ? :capture : :swing_up
    elseif controller.mode == :capture && !in_capture_band(controller, state)
        controller.mode = :swing_up
    elseif controller.mode != :stabilize && in_capture_region(controller, state)
        controller.mode = :stabilize
    elseif controller.mode == :swing_up && in_capture_band(controller, state)
        controller.mode = :capture
    end

    return controller.mode
end

function control!(controller::HybridController, state::AbstractVector)
    update_mode!(controller, state)

    if controller.mode == :stabilize
        force = stabilize_force!(controller, state)
    elseif controller.mode == :capture
        clear_solver_status!(controller)
        controller.last_energy_error = target_energy(controller.params) - total_energy(controller.params, state)
        force = fallback_balance_force(controller, state)
    else
        clear_solver_status!(controller)
        force = swing_up_force(controller, state)
    end

    controller.last_force = force
    return force
end

function warmup!(controller::HybridController)
    warm_state = [0.0, 0.0, 0.08, 0.0, -0.06, 0.0]
    controller.mode = :stabilize
    control!(controller, warm_state)
    controller.mode = :swing_up
    controller.last_force = 0.0
    controller.last_energy_error = 0.0
    clear_solver_status!(controller)
    reset_cache!(controller.cache)
    return controller
end
