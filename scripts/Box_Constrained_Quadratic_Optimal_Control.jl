using LinearAlgebra
using JuMP
using BenchmarkTools
using JuMP
using Ipopt
using OptimalControl_OperatorSplitting

function box_constrained_quadratic_ocp(n, m, T)
    # --- Generate System Dynamics ---
    A_rand = randn(n, n)
    B = randn(n, m)

    max_eig = maximum(abs.(eigvals(A_rand)))
    A = A_rand ./ max_eig

    c = zeros(n, T)

    x0 = randn(n) * 10.0 

    # --- Generate Cost Matrices ---
    Q = Matrix(1.0 * I(n)) 
    R = Matrix(0.1 * I(m)) 
    S = zeros(n, m)        

    q = zeros(n, T+1)
    r = zeros(m, T+1)

    return A, B, c, Q, S, R, q, r, x0
end

# proximal operator
function box_proximal!(x_tilde, u_tilde, v, w, rho)
    # The state has no constraints, so it just equals the anchor point v
    x_tilde .= v
    
    # The control is box-constrained, so we saturate w between -1 and 1
    u_tilde .= clamp.(w, -1.0, 1.0)
end

# Run the solver
function solve_box_constrained_ocp()
    n = 4  
    m = 2  
    T = 20 

    A, B, c, Q, S, R, q, r, x0 = box_constrained_quadratic_ocp(n, m, T)

    data = OptimalControl_OperatorSplitting.all_data(A, B, c, Q, S, R, q, r, x0; rho=50.0)
    x_opt, u_opt, tt = OptimalControl_OperatorSplitting.solve(data, box_proximal!; max_iters=50)
end



# --- 1. The Ipopt-Based Proximal Operator ---
function ipopt_box_proximal!(x_tilde, u_tilde, v, w, rho)
    n, num_steps = size(v)
    m = size(w, 1)
    
    # The proximal step is separable across time, so we solve T+1 independent problems.
    # We use Threads.@threads to parallelize this across your CPU cores.
    Threads.@threads for t in 1:num_steps
        
        # Initialize the interior-point solver for this specific time step
        model = Model(Ipopt.Optimizer)
        set_silent(model) 
        
        # Define the variables for this time step
        @variable(model, xt[1:n])
        @variable(model, ut[1:m])
        
        # Apply the exact same box constraints: ||u_t||_∞ ≤ 1
        @constraint(model, -1.0 .<= ut .<= 1.0)
        
        # Apply the proximal "rubber band" objective anchored to v[:, t] and w[:, t]
        @objective(model, Min, 
            (rho / 2.0) * (sum((xt[i] - v[i, t])^2 for i in 1:n) + 
                           sum((ut[j] - w[j, t])^2 for j in 1:m))
        )
        
        # Solve the interior point problem
        optimize!(model)
        
        # Write the optimal values back into the pre-allocated arrays in-place
        x_tilde[:, t] .= value.(xt)
        u_tilde[:, t] .= value.(ut)
    end
end

# --- 2. The Ipopt Solver Runner ---
function solve_box_constrained_ocp_ipopt()
    n = 4  
    m = 2  
    T = 20 

    # Generate the exact same problem structure
    A, B, c, Q, S, R, q, r, x0 = box_constrained_quadratic_ocp(n, m, T)

    # Run the solver using the Ipopt proximal step
    data = OptimalControl_OperatorSplitting.all_data(A, B, c, Q, S, R, q, r, x0; rho=50.0)
    x_opt, u_opt, tt = OptimalControl_OperatorSplitting.solve(data, ipopt_box_proximal!; max_iters=50)
end

# --- 3. The Benchmark Showdown ---
println("Benchmarking Analytical Proximal Step...")
@btime solve_box_constrained_ocp()

println("\nBenchmarking Ipopt Proximal Step...")
@btime solve_box_constrained_ocp_ipopt()
