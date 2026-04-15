struct CartDoublePendulumParams
    cart_mass::Float64
    link1_mass::Float64
    link2_mass::Float64
    link1_length::Float64
    link2_length::Float64
    gravity::Float64
    cart_damping::Float64
    joint1_damping::Float64
    joint2_damping::Float64
    cart_half_width::Float64
    cart_half_height::Float64
end

function default_cart_double_pendulum_params(; cart_mass=1.0,
    link1_mass=0.35,
    link2_mass=0.2,
    link1_length=0.8,
    link2_length=0.65,
    gravity=9.81,
    cart_damping=0.35,
    joint1_damping=0.06,
    joint2_damping=0.04,
    cart_half_width=0.22,
    cart_half_height=0.12)
    return CartDoublePendulumParams(
        cart_mass,
        link1_mass,
        link2_mass,
        link1_length,
        link2_length,
        gravity,
        cart_damping,
        joint1_damping,
        joint2_damping,
        cart_half_width,
        cart_half_height,
    )
end

wrap_angle(angle) = mod(angle + pi, 2pi) - pi

function wrap_state!(state::AbstractVector)
    state[3] = wrap_angle(state[3])
    state[5] = wrap_angle(state[5])
    return state
end

function link_positions(params::CartDoublePendulumParams, state::AbstractVector)
    cart_x = state[1]
    pivot_x = cart_x
    pivot_y = params.cart_half_height
    bob1_x = pivot_x + params.link1_length * sin(state[3])
    bob1_y = pivot_y + params.link1_length * cos(state[3])
    bob2_x = bob1_x + params.link2_length * sin(state[5])
    bob2_y = bob1_y + params.link2_length * cos(state[5])

    return (
        pivot=(pivot_x, pivot_y),
        bob1=(bob1_x, bob1_y),
        bob2=(bob2_x, bob2_y),
    )
end

function target_energy(params::CartDoublePendulumParams)
    return (params.link1_mass + params.link2_mass) * params.gravity * params.link1_length +
        params.link2_mass * params.gravity * params.link2_length
end

function total_energy(params::CartDoublePendulumParams, state::AbstractVector)
    xdot = state[2]
    theta1 = state[3]
    omega1 = state[4]
    theta2 = state[5]
    omega2 = state[6]

    l1 = params.link1_length
    l2 = params.link2_length
    m1 = params.link1_mass
    m2 = params.link2_mass
    mc = params.cart_mass
    g = params.gravity

    v1_sq = xdot^2 + 2 * xdot * l1 * cos(theta1) * omega1 + l1^2 * omega1^2
    v2_sq = xdot^2 +
        2 * xdot * (l1 * cos(theta1) * omega1 + l2 * cos(theta2) * omega2) +
        l1^2 * omega1^2 + l2^2 * omega2^2 +
        2 * l1 * l2 * cos(theta1 - theta2) * omega1 * omega2

    kinetic = 0.5 * mc * xdot^2 + 0.5 * m1 * v1_sq + 0.5 * m2 * v2_sq
    potential = (m1 + m2) * g * l1 * cos(theta1) + m2 * g * l2 * cos(theta2)
    return kinetic + potential
end

function mass_matrix(params::CartDoublePendulumParams, state::AbstractVector)
    theta1 = state[3]
    theta2 = state[5]

    mc = params.cart_mass
    m1 = params.link1_mass
    m2 = params.link2_mass
    l1 = params.link1_length
    l2 = params.link2_length

    m11 = mc + m1 + m2
    m12 = (m1 + m2) * l1 * cos(theta1)
    m13 = m2 * l2 * cos(theta2)
    m22 = (m1 + m2) * l1^2
    m23 = m2 * l1 * l2 * cos(theta1 - theta2)
    m33 = m2 * l2^2

    return [m11 m12 m13; m12 m22 m23; m13 m23 m33]
end

function bias_terms(params::CartDoublePendulumParams, state::AbstractVector)
    theta1 = state[3]
    omega1 = state[4]
    theta2 = state[5]
    omega2 = state[6]

    m1 = params.link1_mass
    m2 = params.link2_mass
    l1 = params.link1_length
    l2 = params.link2_length
    g = params.gravity
    delta = theta1 - theta2

    return [
        -(m1 + m2) * l1 * sin(theta1) * omega1^2 - m2 * l2 * sin(theta2) * omega2^2,
        m2 * l1 * l2 * sin(delta) * omega2^2 - (m1 + m2) * g * l1 * sin(theta1),
        -m2 * l1 * l2 * sin(delta) * omega1^2 - m2 * g * l2 * sin(theta2),
    ]
end

function generalized_forces(params::CartDoublePendulumParams, state::AbstractVector, force)
    return [
        force - params.cart_damping * state[2],
        -params.joint1_damping * state[4],
        -params.joint2_damping * state[6],
    ]
end

function continuous_dynamics(params::CartDoublePendulumParams, state::AbstractVector, force)
    rhs = generalized_forces(params, state, force) - bias_terms(params, state)
    accelerations = mass_matrix(params, state) \ rhs
    T = promote_type(eltype(state), typeof(force))

    return T[
        state[2],
        accelerations[1],
        state[4],
        accelerations[2],
        state[6],
        accelerations[3],
    ]
end

function rk4_step(params::CartDoublePendulumParams, state::AbstractVector{<:Real}, force, dt)
    k1 = continuous_dynamics(params, state, force)
    k2 = continuous_dynamics(params, state .+ 0.5 * dt .* k1, force)
    k3 = continuous_dynamics(params, state .+ 0.5 * dt .* k2, force)
    k4 = continuous_dynamics(params, state .+ dt .* k3, force)

    next_state = state .+ (dt / 6.0) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    wrap_state!(next_state)
    return next_state
end

function upright_error(state::AbstractVector)
    return (
        angle=max(abs(wrap_angle(state[3])), abs(wrap_angle(state[5]))),
        rate=max(abs(state[4]), abs(state[6])),
    )
end