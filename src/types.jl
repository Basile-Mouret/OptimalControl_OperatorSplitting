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

function prob_vars(data::all_data{Tv}) where {Tv<:AbstractFloat}
    x = zeros(Tv, data.n, data.T + 1)
    u = zeros(Tv, data.m, data.T + 1)
    x_t = zeros(Tv, data.n, data.T + 1)
    u_t = zeros(Tv, data.m, data.T + 1)
    z = zeros(Tv, data.n, data.T + 1)
    y = zeros(Tv, data.m, data.T + 1)

    x_t[:, 1] = data.x_init
    return prob_vars(x, u, x_t, u_t, z, y)
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

struct solver_cache{Tv<:AbstractFloat,Td,Tf}
    data::Td
    factorization::Tf
    dim_w::Int
    rhs::Vector{Tv}
    sol::Vector{Tv}
    v::Matrix{Tv}
    w::Matrix{Tv}
    x_t_prev::Matrix{Tv}
    u_t_prev::Matrix{Tv}
end

Timings{Tv}() where {Tv<:AbstractFloat} = Timings{Tv}(
    zero(Tv),
    zero(Tv),
    zero(Tv),
    0,
    zero(Tv),
    zero(Tv),
    zero(Tv),
    zero(Tv),
    false,
)

Timings() = Timings{Float64}()

Base.eltype(::all_data{Tv}) where {Tv<:AbstractFloat} = Tv
Base.eltype(::prob_vars{Tv}) where {Tv<:AbstractFloat} = Tv
