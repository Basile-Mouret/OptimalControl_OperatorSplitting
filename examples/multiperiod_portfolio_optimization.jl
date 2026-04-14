using LinearAlgebra
using Random
using JuMP
using BenchmarkTools
using Ipopt
using OptimalControl_OperatorSplitting

"""
Generate one instance of the OSC multiperiod portfolio example.

The construction follows `finance/gen_data.m` in cvxgrp/osc.
"""
function multiperiod_portfolio_data(n::Int, T::Int; lambda::Float64=0.4, seed::Int=0)
	Random.seed!(seed)

	m = n
	x0 = zeros(n)
	x_term = copy(x0)
	c = zeros(n, T)

	s = 0.2 .+ 0.1 .* rand(n)
	kappa = 0.1 .* rand(n)

	# Covariance generation (same recipe as OSC MATLAB script)
	sigma_tilde_diag = 0.01 .* rand(n)
	temp = randn(n, n)
	temp = temp * temp'
	l1 = 0.0
	l2 = 10.0
	v1 = rand(n) .< 0.8
	v2 = rand(n) .< 0.8
	Y = temp .+ l1 .* (Float64.(v1) * Float64.(v1)') .+ l2 .* (Float64.(v2) * Float64.(v2)')
	d = 1.0 ./ sqrt.(diag(Y))
	C = Diagonal(d) * Y * Diagonal(d)

	sigma_tilde = C .* (sqrt.(sigma_tilde_diag) * sqrt.(sigma_tilde_diag)')
	mu = 0.03 .* rand(n)
	r_bar = exp.(mu .+ 0.5 .* diag(sigma_tilde))
	sigma = (r_bar * r_bar') .* (exp.(sigma_tilde) .- 1.0)
	sigma = 0.5 .* (sigma .+ sigma')

	A = Diagonal(r_bar)
	B = copy(A)

	Q = 2.0 .* lambda .* sigma
	S = 2.0 .* lambda .* sigma
	R = 2.0 .* (lambda .* sigma .+ Diagonal(s))
	q = zeros(n, T + 1)
	r = ones(m, T + 1)

	phi = (Q, S, R, q, r)
	return phi, Matrix(A), Matrix(B), c, x0, x_term, kappa
end

@inline pos(x::Float64) = x > 0.0 ? x : 0.0

@inline function soft_thresh(x::Float64, gamma::Float64)
	ax = abs(x)
	return ax == 0.0 ? 0.0 : x * pos(1.0 - gamma / ax)
end

"""
Analytical proximal operator for the finance example.

For each time step and asset this solves the prox of:
- `kappa .* abs.(u)`
- `x + u >= 0` for all stages
- `x_T + u_T = x_term` at the terminal stage.
"""
function portfolio_proximal_factory!(kappa::Vector{Float64}, x_term::Vector{Float64})
	function portfolio_proximal!(x_tilde, u_tilde, v, w, rho)
		n, num_steps = size(v)
		T = num_steps - 1

		for t in 1:T
			@inbounds for j in 1:n
				temp = soft_thresh(w[j, t], kappa[j] / rho)
				if v[j, t] + temp >= 0.0
					x_tilde[j, t] = v[j, t]
					u_tilde[j, t] = temp
				else
					ut2 = soft_thresh((w[j, t] - v[j, t]) / 2.0, kappa[j] / (2.0 * rho))
					u_tilde[j, t] = ut2
					x_tilde[j, t] = -ut2
				end
			end
		end

		t = T + 1
		@inbounds for j in 1:n
			ut = soft_thresh((w[j, t] - v[j, t] + x_term[j]) / 2.0, kappa[j] / (2.0 * rho))
			u_tilde[j, t] = ut
			x_tilde[j, t] = x_term[j] - ut
		end

		return nothing
	end

	return portfolio_proximal!
end

function solve_multiperiod_portfolio_ocp(; n::Int=30, T::Int=60, max_iters::Int=27, rho::Float64=0.1, seed::Int=0)
	phi, A, B, c, x0, x_term, kappa = multiperiod_portfolio_data(n, T; seed=seed)
	prox_operator! = portfolio_proximal_factory!(kappa, x_term)

	data = OptimalControl_OperatorSplitting.all_data(A, B, c, phi[1], phi[2], phi[3], phi[4], phi[5], x0; rho=rho, alpha=1.8)
	cache = OptimalControl_OperatorSplitting.setup_cache(data)
	x_opt, u_opt, tt = OptimalControl_OperatorSplitting.solve(cache, prox_operator!; max_iters=max_iters)

	return x_opt, u_opt, tt
end

# Small test n=10 T=30
println("Benchmarking Multiperiod Portfolio Optimization... (Small : n=10, T=30)")
x_opt, u_opt, tt = solve_multiperiod_portfolio_ocp(n=10, T=30)
display(tt)

# Medium test n=30 T=60
println("Benchmarking Multiperiod Portfolio Optimization... (n=30, T=60)")
x_opt, u_opt, tt = solve_multiperiod_portfolio_ocp(n=30, T=60)
display(tt)

# Large test n=50 T=100
println("Benchmarking Multiperiod Portfolio Optimization... (Large : n=50, T=100)")
x_opt, u_opt, tt = solve_multiperiod_portfolio_ocp(n=50, T=100)
display(tt)