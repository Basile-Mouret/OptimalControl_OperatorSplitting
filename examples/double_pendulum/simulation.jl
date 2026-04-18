if abspath(something(Base.active_project(), "")) != abspath(joinpath(@__DIR__, "Project.toml"))
    import Pkg
    Pkg.activate(@__DIR__; io=devnull)
end

using GLMakie
using Printf

include("model.jl")
include("controller.jl")

initial_state(kind::Symbol) = kind == :upright ?
    [0.0, 0.0, 0.08, 0.0, -0.05, 0.0] :
    [0.0, 0.0, 1.4, 0.0, -1.1, 0.0]

function parse_args(args)
    headless = false
    realtime = true
    duration = 20.0
    initial_condition = :swingup

    for arg in args
        if arg == "--headless"
            headless = true
        elseif arg == "--no-realtime"
            realtime = false
        elseif arg == "--upright"
            initial_condition = :upright
        elseif startswith(arg, "--duration=")
            duration = parse(Float64, split(arg, "="; limit=2)[2])
        else
            error("Unknown argument: $(arg)")
        end
    end

    return (; headless, realtime, duration, initial_condition)
end

function cart_outline(params::CartDoublePendulumParams, state::AbstractVector)
    x = state[1]
    left = x - params.cart_half_width
    right = x + params.cart_half_width
    bottom = -params.cart_half_height
    top = params.cart_half_height

    return Point2f[
        Point2f(left, bottom),
        Point2f(right, bottom),
        Point2f(right, top),
        Point2f(left, top),
    ]
end

function scene_geometry(params::CartDoublePendulumParams, state::AbstractVector)
    positions = link_positions(params, state)

    return (
        cart=cart_outline(params, state),
        link1=Point2f[
            Point2f(positions.pivot...),
            Point2f(positions.bob1...),
        ],
        link2=Point2f[
            Point2f(positions.bob1...),
            Point2f(positions.bob2...),
        ],
        masses=Point2f[
            Point2f(positions.bob1...),
            Point2f(positions.bob2...),
        ],
    )
end

function build_scene(params::CartDoublePendulumParams, state::AbstractVector)
    figure = Figure(size=(1200, 760), backgroundcolor=RGBf(0.96, 0.97, 0.98))
    axis = Axis(
        figure[1, 1],
        title="Cart Double Pendulum: Swing-Up + Operator-Splitting MPC",
        xlabel="Horizontal position (m)",
        ylabel="Height (m)",
        aspect=DataAspect(),
        backgroundcolor=RGBf(0.99, 0.995, 1.0),
    )

    xlims!(axis, -2.6, 2.6)
    ylims!(axis, -2.0, params.link1_length + params.link2_length + 0.45)
    lines!(axis, [-2.8, 2.8], [0.0, 0.0], color=(:black, 0.18), linewidth=4)

    geometry = scene_geometry(params, state)
    cart_points = Observable(geometry.cart)
    link1_points = Observable(geometry.link1)
    link2_points = Observable(geometry.link2)
    mass_points = Observable(geometry.masses)
    trace_points = Observable(Point2f[])
    status_text = Observable("Initializing simulation...")

    poly!(axis, cart_points, color=RGBf(0.16, 0.34, 0.58), strokecolor=RGBf(0.07, 0.15, 0.28), strokewidth=2)
    lines!(axis, trace_points, color=(:orange, 0.55), linewidth=2)
    lines!(axis, link1_points, color=RGBf(0.77, 0.28, 0.23), linewidth=7)
    lines!(axis, link2_points, color=RGBf(0.21, 0.54, 0.39), linewidth=7)
    scatter!(axis, mass_points, color=[RGBf(0.77, 0.28, 0.23), RGBf(0.21, 0.54, 0.39)], markersize=24)
    scatter!(axis, [Point2f(state[1], params.cart_half_height)], color=RGBf(0.07, 0.15, 0.28), markersize=12)

    Label(figure[2, 1], status_text; tellwidth=false, halign=:left, justification=:left, padding=(10, 10, 10, 10))

    return (
        figure=figure,
        cart_points=cart_points,
        link1_points=link1_points,
        link2_points=link2_points,
        mass_points=mass_points,
        trace_points=trace_points,
        status_text=status_text,
    )
end

function update_scene!(scene, params::CartDoublePendulumParams, state::AbstractVector, trace::Vector{Point2f}, status::AbstractString)
    geometry = scene_geometry(params, state)
    scene.cart_points[] = geometry.cart
    scene.link1_points[] = geometry.link1
    scene.link2_points[] = geometry.link2
    scene.mass_points[] = geometry.masses
    scene.trace_points[] = copy(trace)
    scene.status_text[] = status
    return nothing
end

function wait_for_start!(scene, screen, params::CartDoublePendulumParams, controller::HybridController, state::AbstractVector, trace::Vector{Point2f})
    started = Ref(false)
    on(events(scene.figure).keyboardbutton) do event
        if event.key == Keyboard.space && event.action == Keyboard.press
            started[] = true
        end
    end

    update_scene!(scene, params, state, trace, "Press space to start the simulation\n" * status_string(0.0, controller, state))

    while isopen(screen) && !started[]
        yield()
        sleep(1 / 60)
    end

    return started[]
end

function status_string(simulation_time, controller::HybridController, state::AbstractVector)
    error = upright_error(state)

    return @sprintf(
        "t = %.2f s   mode = %s   force = %+5.2f N   energy err = %+6.2f J\nangle err = %.3f rad   rate err = %.3f rad/s   solve = %.2f ms   ADMM iters = %d   converged = %s",
        simulation_time,
        string(controller.mode),
        controller.last_force,
        controller.last_energy_error,
        error.angle,
        error.rate,
        controller.last_solver_ms,
        controller.last_iterations,
        controller.last_converged ? "yes" : "no",
    )
end

function simulation_summary(state::AbstractVector, controller::HybridController, average_solver_ms, controller_calls, render_count, late_frames)
    final_error = upright_error(state)

    return (
        final_state=state,
        final_mode=controller.mode,
        final_angle_error=final_error.angle,
        final_rate_error=final_error.rate,
        average_solver_ms=average_solver_ms,
        controller_calls=controller_calls,
        rendered_frames=render_count,
        late_frames=late_frames,
    )
end

function print_summary(summary)
    println(@sprintf(
        "Summary: mode=%s angle_err=%.3f rate_err=%.3f avg_solve=%.2f ms frames=%d late=%d",
        string(summary.final_mode),
        summary.final_angle_error,
        summary.final_rate_error,
        summary.average_solver_ms,
        summary.rendered_frames,
        summary.late_frames,
    ))
    return nothing
end

function run_simulation(; duration=20.0, headless=false, realtime=true, initial_condition=:swingup)
    params = default_cart_double_pendulum_params()
    controller = build_hybrid_controller(params)
    warmup!(controller)

    simulation_dt = 0.005
    render_dt = 1 / 30
    control_dt = controller.config.dt

    state = initial_state(initial_condition)
    trace = Point2f[]
    screen = nothing
    scene = nothing
    render_count = 0
    late_frames = 0
    controller_calls = 0
    solver_time_sum = 0.0

    if !headless
        scene = build_scene(params, state)
        screen = display(scene.figure)
        if !wait_for_start!(scene, screen, params, controller, state, trace)
            summary = simulation_summary(state, controller, 0.0, 0, 0, 0)
            print_summary(summary)
            return summary
        end
    end

    force = 0.0
    simulation_time = 0.0
    next_control_time = 0.0
    next_render_time = 0.0
    wall_start = time()

    while simulation_time < duration && (headless || isopen(screen))
        if simulation_time + 1e-9 >= next_control_time
            force = control!(controller, state)
            controller_calls += 1
            solver_time_sum += controller.last_solver_ms
            next_control_time += control_dt
        end

        state = rk4_step(params, state, force, simulation_dt)
        simulation_time += simulation_dt

        if simulation_time + 1e-9 >= next_render_time
            render_count += 1
            push!(trace, Point2f(link_positions(params, state).bob2...))
            if length(trace) > 240
                popfirst!(trace)
            end

            status = status_string(simulation_time, controller, state)

            if !headless
                update_scene!(scene, params, state, trace, status)
                if realtime
                    target_wall = wall_start + simulation_time
                    slack = target_wall - time()
                    if slack > 0.0
                        sleep(slack)
                    else
                        late_frames += 1
                    end
                end
            end

            next_render_time += render_dt
        end
    end

    average_solver_ms = controller_calls == 0 ? 0.0 : solver_time_sum / controller_calls
    summary = simulation_summary(state, controller, average_solver_ms, controller_calls, render_count, late_frames)
    print_summary(summary)

    if !headless
        wait(screen)
    end

    return summary
end

function main(args=ARGS)
    options = parse_args(args)
    return run_simulation(
        ;
        duration=options.duration,
        headless=options.headless,
        realtime=options.realtime,
        initial_condition=options.initial_condition,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
