if abspath(something(Base.active_project(), "")) != abspath(joinpath(@__DIR__, "Project.toml"))
	import Pkg
	Pkg.activate(@__DIR__; io=devnull)
end

using GLMakie
using Printf

include("model.jl")
include("controller.jl")

function initial_state(kind::Symbol)
	if kind == :upright
		return [0.0, 0.0, 0.08, 0.0, -0.05, 0.0]
	end

	return [0.0, 0.0, 1.4, 0.0, -1.1, 0.0]
end

function parse_args(args)
	options = Dict(
		:headless => false,
		:realtime => true,
		:duration => 20.0,
		:initial_condition => :swingup,
	)

	for arg in args
		if arg == "--headless"
			options[:headless] = true
		elseif arg == "--no-realtime"
			options[:realtime] = false
		elseif arg == "--upright"
			options[:initial_condition] = :upright
		elseif startswith(arg, "--duration=")
			options[:duration] = parse(Float64, split(arg, "="; limit=2)[2])
		else
			error("Unknown argument: $(arg)")
		end
	end

	return options
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
	ylims!(axis, -0.55, params.link1_length + params.link2_length + 0.45)
	lines!(axis, [-2.8, 2.8], [0.0, 0.0], color=(:black, 0.18), linewidth=4)

	cart_points = Observable(cart_outline(params, state))
	bob_positions = link_positions(params, state)
	link1_points = Observable(Point2f[
		Point2f(bob_positions.pivot...),
		Point2f(bob_positions.bob1...),
	])
	link2_points = Observable(Point2f[
		Point2f(bob_positions.bob1...),
		Point2f(bob_positions.bob2...),
	])
	mass_points = Observable(Point2f[
		Point2f(bob_positions.bob1...),
		Point2f(bob_positions.bob2...),
	])
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

function update_scene!(scene, params::CartDoublePendulumParams, state::AbstractVector, trace::Vector{Point2f}, status)
	positions = link_positions(params, state)
	scene.cart_points[] = cart_outline(params, state)
	scene.link1_points[] = Point2f[
		Point2f(positions.pivot...),
		Point2f(positions.bob1...),
	]
	scene.link2_points[] = Point2f[
		Point2f(positions.bob1...),
		Point2f(positions.bob2...),
	]
	scene.mass_points[] = Point2f[
		Point2f(positions.bob1...),
		Point2f(positions.bob2...),
	]
	scene.trace_points[] = copy(trace)
	scene.status_text[] = status
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
	linearization_time_sum = 0.0

	if !headless
		scene = build_scene(params, state)
		screen = display(scene.figure)
	end

	force = 0.0
	simulation_time = 0.0
	next_control_time = 0.0
	next_render_time = 0.0
	wall_start = time()

	while simulation_time < duration
		if simulation_time + 1e-9 >= next_control_time
			force = control!(controller, state)
			controller_calls += 1
			solver_time_sum += controller.last_solver_ms
			linearization_time_sum += controller.last_linearization_ms
			next_control_time += control_dt
		end

		state = rk4_step(params, state, force, simulation_dt)
		simulation_time += simulation_dt

		if simulation_time + 1e-9 >= next_render_time
			render_count += 1
			positions = link_positions(params, state)
			push!(trace, Point2f(positions.bob2...))
			if length(trace) > 240
				popfirst!(trace)
			end

			snapshot = controller_snapshot(controller)
			error = upright_error(state)
			status = @sprintf(
				"t = %.2f s   mode = %s   force = %+5.2f N   energy err = %+6.2f J\nangle err = %.3f rad   rate err = %.3f rad/s   solve = %.2f ms   linearize = %.2f ms   ADMM iters = %d   converged = %s",
				simulation_time,
				string(snapshot.mode),
				snapshot.force,
				snapshot.energy_error,
				error.angle,
				error.rate,
				snapshot.solver_ms,
				snapshot.linearization_ms,
				snapshot.iterations,
				snapshot.converged ? "yes" : "no",
			)

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
	average_linearization_ms = controller_calls == 0 ? 0.0 : linearization_time_sum / controller_calls
	final_error = upright_error(state)

	summary = (
		final_state=state,
		final_mode=controller.mode,
		final_angle_error=final_error.angle,
		final_rate_error=final_error.rate,
		average_solver_ms=average_solver_ms,
		average_linearization_ms=average_linearization_ms,
		controller_calls=controller_calls,
		rendered_frames=render_count,
		late_frames=late_frames,
	)

	println(@sprintf(
		"Summary: mode=%s angle_err=%.3f rate_err=%.3f avg_solve=%.2f ms avg_linearize=%.2f ms frames=%d late=%d",
		string(summary.final_mode),
		summary.final_angle_error,
		summary.final_rate_error,
		summary.average_solver_ms,
		summary.average_linearization_ms,
		summary.rendered_frames,
		summary.late_frames,
	))

	if !headless
		wait(screen)
	end

	return summary
end

function main(args=ARGS)
	options = parse_args(args)
	return run_simulation(
		;
		duration=options[:duration],
		headless=options[:headless],
		realtime=options[:realtime],
		initial_condition=options[:initial_condition],
	)
end

if abspath(PROGRAM_FILE) == @__FILE__
	main()
end
