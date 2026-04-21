#!/usr/bin/env julia
using OptimalControl_OperatorSplitting
using Plots
using LinearAlgebra
using Statistics

gr()  # Use GR backend

println("=== Box-Constrained Optimal Control: Speed Stabilization ===")
flush(stdout)

# Problem: Stabilize velocity using bounded acceleration
# State: x = [position, velocity]
# Control: u = acceleration
# Dynamics: x_{k+1} = A*x_k + B*u_k
# Constraints: a_min <= u_k <= a_max

# System parameters
dt = 0.1      # Time step
n = 2         # State dimension: [position, velocity]
m = 1         # Control dimension: acceleration
T = 100       # Horizon (increased to 100 for long cruising phase)

# Dynamics: position and velocity
A_k = [1.0  dt;    # pos_{k+1} = pos_k + dt*vel_k
       0.0  1.0]   # vel_{k+1} = vel_k (+ acceleration in cost)

B_k = [0.0;        # position not directly affected
       dt]         # velocity changes by dt*accel

# Control bounds
a_min = -0.5       # Min acceleration
a_max = 0.5        # Max acceleration

# Cost matrices
# Objective: minimize sum_k ||x_k - x_target||_Q^2 + lambda*u_k^2 + penalty_on_velocity_deviation
Q = [0.0   0.0;       # No penalty on position
     0.0   50.0]      # VERY strong penalty on velocity deviation

S = zeros(n, m)       # No cross terms
R = [0.1]             # Moderate penalty on acceleration to encourage less aggressive control

# Terminal cost: EXTREMELY strong penalty to enforce velocity target
Q_terminal = [0.0  0.0;
              0.0  500.0]  # Huge penalty to reach target velocity exactly

# Target state: [any position, 1.0 m/s]
x_target = [0.0; 1.0]

# Linear cost terms: q = -Q*x_target, r = 0
q = zeros(n, T + 1)
r = zeros(m, T + 1)

# Regular stages
for t in 1:T
    q[:, t] .= -Q * x_target
end

# Terminal stage with strong penalty
q[:, T + 1] .= -Q_terminal * x_target

# Initial state: at origin with zero velocity
x_init = [0.0; 0.0]

# Problem parameters
rho = 50.0
alpha = 1.8
eps_abs = 1e-3
eps_rel = 1e-3
reg = 1e-6

# Expand into 3D arrays
A_3d = zeros(n, n, T)
B_3d = zeros(n, m, T)
Q_3d = zeros(n, n, T + 1)
S_3d = zeros(n, m, T + 1)
R_3d = zeros(m, m, T + 1)
c_vec = zeros(n, T)

for t in 1:T
    A_3d[:, :, t] .= A_k
    B_3d[:, :, t] .= B_k
    Q_3d[:, :, t] .= Q
    S_3d[:, :, t] .= S
    R_3d[:, :, t] .= R
end

Q_3d[:, :, T + 1] .= Q_terminal
S_3d[:, :, T + 1] .= S
R_3d[:, :, T + 1] .= R

# Create problem data
println("Creating optimal control problem...")
println("  States: position, velocity")
println("  Control: acceleration with bounds [$a_min, $a_max] m/s²")
println("  Target state: position=any, velocity=$(x_target[2]) m/s")
println("  Horizon: T = $T steps (~$(T*dt) seconds)")
flush(stdout)

data = all_data(
    A_3d, B_3d, c_vec, Q_3d, S_3d, R_3d, q, r, x_init;
    rho=rho, alpha=alpha, eps_abs=eps_abs, eps_rel=eps_rel, reg=reg
)

# Define box proximal operator for acceleration bounds
function accel_proximal!(x_tilde, u_tilde, v, w, rho)
    x_tilde .= v
    u_tilde .= clamp.(w, a_min, a_max)
end

println("Solving...")
cache = setup_cache(data)
x, u, tt = solve(cache, accel_proximal!; max_iters=3000)

println("✓ Converged=$(tt.converged) in $(tt.itns) iterations")
println("  Total time: $(round(tt.total_time; digits=2)) ms")
flush(stdout)

# Extract trajectories
time_steps = collect(0:T) .* dt
position = x[1, :]
velocity = x[2, :]
acceleration = u[1, :]

# ===== Plot 1: Velocity vs time with target =====
println("Creating velocity plot...")
p_vel = plot(title="Optimal Trajectory: Velocity", 
             xlabel="Time (s)", ylabel="Velocity (m/s)", 
             legend=:topright, size=(900, 500), margin=5Plots.mm,
             gridlinewidth=0.5)

plot!(p_vel, time_steps, velocity, label="velocity (actual)", linewidth=2.5, 
      marker=:circle, markersize=3, color=:darkblue)
hline!(p_vel, [1.0], label="target velocity = 1.0 m/s", linewidth=2, 
       linestyle=:dash, color=:green, alpha=0.7)
plot!(p_vel, xlim=(0, T*dt), ylim=(0, 1.5))

# ===== Plot 2: Control (acceleration) with constraints =====
println("Creating acceleration plot...")
p_accel = plot(title="Optimal Control: Acceleration (with Box Constraints)", 
               xlabel="Time (s)", ylabel="Acceleration (m/s²)", 
               legend=:topright, size=(900, 500), margin=5Plots.mm,
               gridlinewidth=0.5)

# Plot acceleration trajectory
plot!(p_accel, time_steps, acceleration, label="acceleration (optimal)", 
      linewidth=2.5, marker=:circle, markersize=3, color=:darkblue)

# Add constraint bounds
hline!(p_accel, [a_max], label="a_max = $a_max m/s²", linewidth=2.5, 
       linestyle=:dash, color=:red, alpha=0.8)
hline!(p_accel, [a_min], label="a_min = $a_min m/s²", linewidth=2.5, 
       linestyle=:dash, color=:red, alpha=0.8)

# Shaded feasible region as a 2D band between the bounds
plot!(p_accel, time_steps, fill(a_max, length(time_steps));
    fillrange=fill(a_min, length(time_steps)),
    fillalpha=0.08, linewidth=0, linealpha=0, label="Feasible region", color=:green)

plot!(p_accel, xlim=(0, T*dt), ylim=(a_min - 0.15, a_max + 0.15))

# ===== Combined plot: velocity and acceleration =====
println("Creating combined plot...")
p_combined = plot(p_vel, p_accel, layout=(2,1), size=(900, 700))

# Save plots
out_dir = joinpath(@__DIR__, "..", "report", "slides", "figures")
mkpath(out_dir)

files_saved = []

p_vel_file = joinpath(out_dir, "speed_control_velocity.png")
savefig(p_vel, p_vel_file)
push!(files_saved, p_vel_file)

p_accel_file = joinpath(out_dir, "speed_control_acceleration.png")
savefig(p_accel, p_accel_file)
push!(files_saved, p_accel_file)

p_combined_file = joinpath(out_dir, "speed_control_combined.png")
savefig(p_combined, p_combined_file)
push!(files_saved, p_combined_file)

println("\n✓ Saved plots:")
for f in files_saved
    println("  - $(basename(f))")
end

# Print summary statistics
println("\n=== Summary ===")
println("Initial state: pos=$(round(position[1]; digits=3)) m, vel=$(round(velocity[1]; digits=3)) m/s")
println("Final state:   pos=$(round(position[end]; digits=3)) m, vel=$(round(velocity[end]; digits=3)) m/s")
println("Target state:  pos=any, vel=$(x_target[2]) m/s")
println("\nVelocity tracking:")
println("  Error at end: $(round(velocity[end] - x_target[2]; digits=4)) m/s")
println("  Max error over horizon: $(round(maximum(abs.(velocity .- x_target[2])); digits=4)) m/s")
println("\nAcceleration statistics:")
println("  Min: $(round(minimum(acceleration); digits=3)) m/s²")
println("  Max: $(round(maximum(acceleration); digits=3)) m/s²")
println("  Mean: $(round(mean(acceleration); digits=3)) m/s²")
println("\nConstraints satisfied: $([all(acceleration .>= a_min - 1e-6) && all(acceleration .<= a_max + 1e-6)])")
