module OptimalControl_OperatorSplitting

using LinearAlgebra, SparseArrays, SuiteSparse

export solve_ocp

function squared_norm_difference(a, b)
    total = 0.0
    @inbounds for idx in eachindex(a, b)
        delta = a[idx] - b[idx]
        total += abs2(delta)
    end
    return total
end

function solve_ocp(
    phi,
    prox_operator!,
    A,
    B,
    c,
    x0,
    T;
    max_iters=100,
    rho=50.0,
    abs_tol=1e-4,
    rel_tol=1e-3,
    primal_tol=nothing,
    dual_tol=nothing,
    return_info=false,
)
    Q, S, R, q, r = phi
    n = size(A, 1)
    m = size(B, 2)
    tolerance_scale = sqrt((T + 1) * (n + m))

    # ---------------------------------------------------------
    # 1. ONE-TIME SETUP 
    # ---------------------------------------------------------
    E_block = [Q + rho*I(n)   S; 
               S'             R + rho*I(m)]
    E = blockdiag([sparse(E_block) for _ in 1:(T+1)]...)
    
    dim_w = (T + 1) * (n + m)
    dim_lambda = (T + 1) * n

    G = spzeros(dim_lambda, dim_w)
    G[1:n, 1:n] = I(n) 
    
    for t in 1:T
        row_start = (t * n) + 1
        row_end   = (t + 1) * n
        col_start_AB = (t - 1) * (n + m) + 1
        col_end_AB   = t * (n + m)
        
        G[row_start:row_end, col_start_AB : col_start_AB + n - 1] = -A
        G[row_start:row_end, col_start_AB + n : col_end_AB] = -B
        
        col_start_I = t * (n + m) + 1
        G[row_start:row_end, col_start_I : col_start_I + n - 1] = I(n)
    end

    eps = 1e-6
    KKT = [E            sparse(G'); 
           G            -eps*I(dim_lambda)]
    F = ldlt(Symmetric(KKT))
    
    h = vcat(x0, vec(c))

    # ---------------------------------------------------------
    # 2. ADMM INITIALIZATION
    # ---------------------------------------------------------
    x_tilde = zeros(n, T+1) 
    x_tilde[:, 1] = x0
    u_tilde = zeros(m, T+1)
    x_tilde_prev = copy(x_tilde)
    u_tilde_prev = copy(u_tilde)

    z = zeros(n, T+1) 
    y = zeros(m, T+1) 
    
    f_matrix = zeros(n+m, T+1)
    x = zeros(n, T+1)
    u = zeros(m, T+1)

    # Pre-allocate anchor point arrays to avoid memory allocations in the loop
    v = zeros(n, T+1)
    w = zeros(m, T+1)

    converged = false
    iterations = max_iters
    primal_residual_norm = Inf
    dual_residual_norm = Inf
    primal_tolerance = Inf
    dual_tolerance = Inf

    # ---------------------------------------------------------
    # 3. MAIN ADMM LOOP
    # ---------------------------------------------------------
    for iter in 1:max_iters
        x_tilde_prev .= x_tilde
        u_tilde_prev .= u_tilde
        
        # --- STEP 1: Quadratic Control Step ---
        for i in 1:(T+1)
            f_matrix[1:n, i] = q[:, i] - rho * (x_tilde[:, i] + z[:, i])
            f_matrix[n+1:end, i] = r[:, i] - rho * (u_tilde[:, i] + y[:, i])
        end
        
        b = vcat(-vec(f_matrix), h)
        sol = F \ b
        
        w_matrix = reshape(sol[1:dim_w], n+m, T+1)
        x .= w_matrix[1:n, :]
        u .= w_matrix[n+1:end, :]

        # --- STEP 2: Single Period Proximal Step ---
        # Calculate the shifted targets (anchor points)
        v .= x .- z
        w .= u .- y

        # Apply the fast analytical proximal operator directly!
        # Because the matrices are passed by reference, this updates them in place.
        prox_operator!(x_tilde, u_tilde, v, w, rho)

        primal_residual_norm = sqrt(
            squared_norm_difference(x, x_tilde) +
            squared_norm_difference(u, u_tilde)
        )
        dual_residual_norm = rho * sqrt(
            squared_norm_difference(x_tilde, x_tilde_prev) +
            squared_norm_difference(u_tilde, u_tilde_prev)
        )
        
        # --- STEP 3: Dual Variable Update ---
        z .= z .+ x_tilde .- x
        y .= y .+ u_tilde .- u

        primal_tolerance = if isnothing(primal_tol)
            abs_tol * tolerance_scale + rel_tol * max(
                sqrt(sum(abs2, x) + sum(abs2, u)),
                sqrt(sum(abs2, x_tilde) + sum(abs2, u_tilde)),
            )
        else
            primal_tol
        end

        dual_tolerance = if isnothing(dual_tol)
            abs_tol * tolerance_scale + rel_tol * sqrt(sum(abs2, z) + sum(abs2, y))
        else
            dual_tol
        end

        if primal_residual_norm <= primal_tolerance && dual_residual_norm <= dual_tolerance
            converged = true
            iterations = iter
            break
        end
        
    end

    info = (
        converged=converged,
        iterations=iterations,
        primal_residual=primal_residual_norm,
        dual_residual=dual_residual_norm,
        primal_tolerance=primal_tolerance,
        dual_tolerance=dual_tolerance,
    )
    
    if return_info
        return x_tilde, u_tilde, info
    end

    return x_tilde, u_tilde
end

end
