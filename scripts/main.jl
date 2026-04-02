using LinearAlgebra
using JuMP
using OSQP # You can also use Clarabel or Ipopt

# --- 1. Problem Data
n = 5
m = 2
T_horizon = 10

B = randn(n, m)
A_raw = randn(n, n)
A = A_raw ./ maximum(abs.(eigvals(A_raw)))
Q_raw = randn(n, n)
Q = Q_raw' * Q_raw
R_raw = randn(m, m)
R = R_raw' * R_raw + 0.1 * I

# Let's define a random initial state
x_init = randn(n) * 10.0 # Multiplied by 10 to encourage control saturation

# --- 2. The "Classic" JuMP Implementation ---

# Initialize the model with the OSQP optimizer
model = Model(OSQP.Optimizer)
set_silent(model) # Optional: hides the solver's print output

# Define variables (Julia is 1-indexed, so time goes from 1 to T+1)
@variable(model, x[1:n, 1:(T_horizon + 1)])
@variable(model, -1 <= u[1:m, 1:(T_horizon + 1)] <= 1) # Box constraints added natively!

# Define the objective function
# Summing the quadratic stage costs over the horizon
@objective(model, Min, 
    0.5 * sum(x[:, t]' * Q * x[:, t] + u[:, t]' * R * u[:, t] for t in 1:(T_horizon + 1))
)

# Define the constraints
# 1. Initial condition
@constraint(model, x[:, 1] .== x_init)

# 2. System dynamics constraint (x_{t+1} = A*x_t + B*u_t)
for t in 1:T_horizon
    @constraint(model, x[:, t+1] .== A * x[:, t] + B * u[:, t])
end

# --- 3. Solve the Problem ---
optimize!(model)

# Extract the optimal trajectories
optimal_u = value.(u)
optimal_x = value.(x)
optimal_cost = objective_value(model)

println("Optimization Status: ", termination_status(model))
println("Optimal Cost: ", optimal_cost)


