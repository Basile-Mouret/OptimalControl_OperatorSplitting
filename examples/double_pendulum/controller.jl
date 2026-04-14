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

mutable struct HybridController
    params::CartDoublePendulumParams
    config::MPCConfig
    balance_a::Matrix{Float64}
    balance_b::Matrix{Float64}
    balance_c::Vector{Float64}
    feedback_gain::Matrix{Float64}
    nominal_states::Matrix{Float64}
    nominal_controls::Matrix{Float64}
    solver_vars::Any
    prox_operator!::Function
    mode::Symbol
    energy_gain::Float64
    shape_gain::Float64
    cart_gain::Float64
    cart_rate_gain::Float64
    last_force::Float64
    last_solver_ms::Float64
    last_linearization_ms::Float64
    last_iterations::Int
    last_converged::Bool
    last_energy_error::Float64
end

function build_hybrid_controller(params::CartDoublePendulumParams; config=default_mpc_config())
    n = 6
    num_cols = config.horizon + 1
    balance_a, balance_b, balance_c = linearize_dynamics(params, zeros(n), 0.0, config.dt)
    feedback_gain = local_lqr_gain(balance_a, balance_b, config.terminal_state_weight, config.stage_input_weight)
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
        Matrix(balance_a),
        Matrix(balance_b),
        Vector(balance_c),
        Matrix(feedback_gain),
        zeros(n, num_cols),
        zeros(1, num_cols),
        nothing,
        prox_operator!,
        :swing_up,
        0.22,
        11.0,
        4.0,
        3.2,
        0.0,
        0.0,
        0.0,
        0,
        false,
        0.0,
    )
end

function controller_snapshot(controller::HybridController)
    return (
        mode=controller.mode,
        force=controller.last_force,
        solver_ms=controller.last_solver_ms,
        linearization_ms=controller.last_linearization_ms,
        iterations=controller.last_iterations,
        converged=controller.last_converged,
        energy_error=controller.last_energy_error,
    )
end

function in_capture_region(controller::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle <= controller.config.capture_enter_angle &&
        error.rate <= controller.config.capture_enter_rate
end

function in_capture_band(controller::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle <= 1.0 && error.rate <= 5.0
end

function outside_balance_region(controller::HybridController, state::AbstractVector)
    error = upright_error(state)
    return error.angle >= controller.config.capture_exit_angle ||
        error.rate >= controller.config.capture_exit_rate
end

function shift_controls!(controller::HybridController)
    controls = controller.nominal_controls
    controls[:, 1:(end - 1)] .= controls[:, 2:end]
    controls[:, end] .= controls[:, end - 1]
    return controls
end

function rollout_nominal(params::CartDoublePendulumParams, x0::AbstractVector, controls::AbstractMatrix, dt)
    n = length(x0)
    horizon = size(controls, 2) - 1
    states = zeros(n, horizon + 1)
    states[:, 1] .= x0

    for stage in 1:horizon
        states[:, stage + 1] .= rk4_step(params, states[:, stage], controls[1, stage], dt)
    end

    return states
end

function rollout_linear_nominal(state::AbstractVector, controls::AbstractMatrix, a_stage::AbstractMatrix, b_stage::AbstractMatrix, c_stage::AbstractVector)
    n = length(state)
    horizon = size(controls, 2) - 1
    states = zeros(n, horizon + 1)
    states[:, 1] .= state

    for stage in 1:horizon
        states[:, stage + 1] .= a_stage * states[:, stage] + b_stage * controls[:, stage] + c_stage
    end

    return states
end

function discrete_dynamics(params::CartDoublePendulumParams, state::AbstractVector, force, dt)
    k1 = continuous_dynamics(params, state, force)
    k2 = continuous_dynamics(params, state .+ 0.5 * dt .* k1, force)
    k3 = continuous_dynamics(params, state .+ 0.5 * dt .* k2, force)
    k4 = continuous_dynamics(params, state .+ dt .* k3, force)
    return state .+ (dt / 6.0) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
end

function linearize_dynamics(params::CartDoublePendulumParams, state_nominal::AbstractVector, force_nominal, dt)
    state_map = state -> discrete_dynamics(params, state, force_nominal, dt)
    input_map = input -> discrete_dynamics(params, state_nominal, input[1], dt)

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

function build_problem_data(controller::HybridController, state::AbstractVector)
    cfg = controller.config
    horizon = cfg.horizon
    n = length(state)

    shift_controls!(controller)
    a_stage = controller.balance_a
    b_stage = controller.balance_b
    c_stage = controller.balance_c
    controller.last_linearization_ms = 0.0

    controller.nominal_states .= rollout_linear_nominal(state, controller.nominal_controls, a_stage, b_stage, c_stage)

    a_matrix = zeros(n, n, horizon)
    b_matrix = zeros(n, 1, horizon)
    affine_term = zeros(n, horizon)

    for stage in 1:horizon
        a_matrix[:, :, stage] .= a_stage
        b_matrix[:, :, stage] .= b_stage
        affine_term[:, stage] .= c_stage
    end

    q_matrix = zeros(n, n, horizon + 1)
    r_matrix = zeros(1, 1, horizon + 1)
    s_matrix = zeros(n, 1, horizon + 1)
    q_vector = zeros(n, horizon + 1)
    r_vector = zeros(1, horizon + 1)

    for stage in 1:horizon
        q_matrix[:, :, stage] .= cfg.stage_state_weight
        r_matrix[:, :, stage] .= cfg.stage_input_weight
    end

    q_matrix[:, :, end] .= cfg.terminal_state_weight
    r_matrix[:, :, end] .= cfg.stage_input_weight

    return all_data(
        a_matrix,
        b_matrix,
        affine_term,
        q_matrix,
        s_matrix,
        r_matrix,
        q_vector,
        r_vector,
        copy(state);
        rho=cfg.rho,
        alpha=1.0,
        eps_abs=cfg.eps_abs,
        eps_rel=cfg.eps_rel,
    )
end

function warm_start!(controller::HybridController, data, state::AbstractVector)
    if controller.solver_vars === nothing
        controller.solver_vars = prob_vars(data)
    end

    vars = controller.solver_vars
    vars.x .= controller.nominal_states
    vars.x_t .= controller.nominal_states
    vars.u .= controller.nominal_controls
    vars.u_t .= controller.nominal_controls
    vars.x[:, 1] .= state
    vars.x_t[:, 1] .= state
    fill!(vars.z, 0.0)
    fill!(vars.y, 0.0)
    return vars
end

function fallback_balance_force(controller::HybridController, state::AbstractVector)
    local_state = copy(state)
    local_state[3] = wrap_angle(local_state[3])
    local_state[5] = wrap_angle(local_state[5])
    force = -(controller.feedback_gain * local_state)[1]
    return clamp(force, -controller.config.max_force, controller.config.max_force)
end

function swing_up_force(controller::HybridController, state::AbstractVector)
    theta1 = wrap_angle(state[3])
    theta2 = wrap_angle(state[5])
    energy_error = target_energy(controller.params) - total_energy(controller.params, state)
    phase = state[4] * cos(theta1) + 0.65 * state[6] * cos(theta2)
    shape = sin(theta1) + 0.7 * sin(theta2)

    force = controller.energy_gain * energy_error * phase -
        controller.shape_gain * shape -
        controller.cart_gain * state[1] -
        controller.cart_rate_gain * state[2]

    controller.last_energy_error = energy_error
    return clamp(force, -controller.config.max_force, controller.config.max_force)
end

function stabilize_force!(controller::HybridController, state::AbstractVector)
    data = build_problem_data(controller, state)
    vars = warm_start!(controller, data, state)
    cache = setup_cache(data)
    timings = solve!(vars, cache, controller.prox_operator!; max_iters=controller.config.max_iters)
    fallback_force = fallback_balance_force(controller, state)

    controller.last_solver_ms = timings.total_time
    controller.last_iterations = timings.itns
    controller.last_converged = timings.converged
    controller.nominal_states .= vars.x_t
    controller.nominal_controls .= vars.u_t

    command = vars.u_t[1, 1]
    if !isfinite(command)
        command = fallback_force
    elseif timings.converged
        command = 0.4 * command + 0.6 * fallback_force
    else
        command = fallback_force
    end

    return clamp(command, -controller.config.max_force, controller.config.max_force)
end

function control!(controller::HybridController, state::AbstractVector)
    if controller.mode == :stabilize && outside_balance_region(controller, state)
        controller.mode = in_capture_band(controller, state) ? :capture : :swing_up
    elseif controller.mode == :capture && !in_capture_band(controller, state)
        controller.mode = :swing_up
    elseif controller.mode != :stabilize && in_capture_region(controller, state)
        controller.mode = :stabilize
    elseif controller.mode == :swing_up && in_capture_band(controller, state)
        controller.mode = :capture
    end

    if controller.mode == :stabilize
        force = stabilize_force!(controller, state)
    elseif controller.mode == :capture
        controller.last_solver_ms = 0.0
        controller.last_linearization_ms = 0.0
        controller.last_iterations = 0
        controller.last_converged = false
        controller.last_energy_error = target_energy(controller.params) - total_energy(controller.params, state)
        force = fallback_balance_force(controller, state)
    else
        controller.last_solver_ms = 0.0
        controller.last_linearization_ms = 0.0
        controller.last_iterations = 0
        controller.last_converged = false
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
    controller.last_solver_ms = 0.0
    controller.last_linearization_ms = 0.0
    controller.last_iterations = 0
    controller.last_converged = false
    controller.last_energy_error = 0.0
    fill!(controller.nominal_controls, 0.0)
    fill!(controller.nominal_states, 0.0)
    controller.solver_vars = nothing
    return controller
end