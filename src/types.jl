#=
Core data types.

Defines the main solver structs: `all_data`, `prob_vars`, `solver_cache`,
and `Timings`.
=#
"""
    all_data{Tv,TA,TB,TC,TQ,TS,TR,Tq,Tr,Tx}

Problem and algorithm data for one finite-horizon control instance.

The struct is immutable and stores precomputed dimensions used throughout the
solver and KKT assembly.
"""
struct all_data{Tv<:AbstractFloat,TA,TB,TC,TQ,TS,TR,Tq,Tr,Tx}
    n::Int
    m::Int
    T::Int
    nc::Int
    rho::Tv
    alpha::Tv
    eps_abs::Tv
    eps_rel::Tv
    reg::Tv
    A::TA
    B::TB
    c::TC
    Q::TQ
    S::TS
    R::TR
    q::Tq
    r::Tr
    x_init::Tx
end

"""
    prob_vars{Tv}

Mutable ADMM iterate storage in stacked-vector form.

Vectors are contiguous and updated in place to avoid per-iteration allocations.
"""
mutable struct prob_vars{Tv<:AbstractFloat}
    x::Vector{Tv}
    u::Vector{Tv}
    x_t::Vector{Tv}
    u_t::Vector{Tv}
    z::Vector{Tv}
    y::Vector{Tv}
end

"""
    Timings{Tv}

Convergence and timing report produced by `solve`.

`lin_sys_time` and `prox_time` are average milliseconds per iteration,
while `total_time` is total wall-clock milliseconds for the solve call.
"""
mutable struct Timings{Tv<:AbstractFloat}
    prox_time::Tv
    lin_sys_time::Tv
    total_time::Tv
    itns::Int
    r_norm::Tv
    s_norm::Tv
    eps_pri::Tv
    eps_dual::Tv
    converged::Bool
end

"""
    solver_cache{Tv,Td,Tf,TRhsLower}

Reusable workspace for repeated solves on fixed structural data.

The cache stores the LDLT factorization, ADMM iterates for warm starts, and
preallocated buffers used in the solve loop.
"""
struct solver_cache{Tv<:AbstractFloat,Td,Tf,TRhsLower}
    data::Td
    vars::prob_vars{Tv}
    factorization::Tf
    rhs::Vector{Tv}
    sol::Vector{Tv}
    rhs_lower::TRhsLower
    v::Vector{Tv}
    w::Vector{Tv}
    x_t_prev::Vector{Tv}
    u_t_prev::Vector{Tv}
end

Base.eltype(::all_data{Tv}) where {Tv<:AbstractFloat} = Tv
Base.eltype(::prob_vars{Tv}) where {Tv<:AbstractFloat} = Tv
