#=
Core data types.

Defines the main solver structs: `all_data`, `prob_vars`, `solver_cache`,
and `Timings`.
=#
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

mutable struct prob_vars{Tv<:AbstractFloat}
    x::Matrix{Tv}
    u::Matrix{Tv}
    x_t::Matrix{Tv}
    u_t::Matrix{Tv}
    z::Matrix{Tv}
    y::Matrix{Tv}
end

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

struct solver_cache{Tv<:AbstractFloat,Td,Tf,TRhsTop,TRhsLower,TSolTop}
    data::Td
    vars::prob_vars{Tv}
    factorization::Tf
    rhs::Vector{Tv}
    sol::Vector{Tv}
    rhs_top::TRhsTop
    rhs_lower::TRhsLower
    sol_top::TSolTop
    v::Matrix{Tv}
    w::Matrix{Tv}
    x_t_prev::Matrix{Tv}
    u_t_prev::Matrix{Tv}
end

Base.eltype(::all_data{Tv}) where {Tv<:AbstractFloat} = Tv
Base.eltype(::prob_vars{Tv}) where {Tv<:AbstractFloat} = Tv
