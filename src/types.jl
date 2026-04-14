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

struct solver_cache{Tv<:AbstractFloat,Td,Tf,TRhsTop,TRhsLower,TSolTop}
    data::Td
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

_fmt_ms(x) = string(round(x; digits=3), " ms")
_fmt_ms_per_iter(x) = string(round(x; digits=3), " ms/iter")
_fmt_sci(x) = string(round(x; sigdigits=4))

function Base.show(io::IO, tt::Timings)
    status = tt.converged ? "converged" : "not converged"
    print(io, "Timings(", status, ", ", tt.itns, " itns, ", _fmt_ms(tt.total_time), ")")
end

function Base.show(io::IO, ::MIME"text/plain", tt::Timings)
    status = tt.converged ? "converged" : "not converged"

    println(io, "Timings")
    println(io, "  status: ", status)
    println(io, "  iterations: ", tt.itns)
    println(io, "  total time: ", _fmt_ms(tt.total_time))
    println(io, "  linear solve: ", _fmt_ms_per_iter(tt.lin_sys_time))
    println(io, "  prox: ", _fmt_ms_per_iter(tt.prox_time))
    println(io, "  primal residual: ", _fmt_sci(tt.r_norm), " (tol ", _fmt_sci(tt.eps_pri), ")")
    print(io, "  dual residual: ", _fmt_sci(tt.s_norm), " (tol ", _fmt_sci(tt.eps_dual), ")")
end

Base.eltype(::all_data{Tv}) where {Tv<:AbstractFloat} = Tv
Base.eltype(::prob_vars{Tv}) where {Tv<:AbstractFloat} = Tv
