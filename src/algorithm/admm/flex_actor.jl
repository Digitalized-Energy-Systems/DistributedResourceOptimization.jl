export ADMMFlexActor, create_admm_flex_actor_one_to_many, result

using JuMP
using OSQP
using LinearAlgebra

mutable struct ADMMFlexActor <: DistributedAlgorithm
    l::Vector{Float64} # lower bounds
    u::Vector{Float64} # upper bounds
    C::Matrix{Float64} # coupling matrix
    d::Vector{Float64} # coupling RHS
    S::Vector{Float64} # prio penalty per sector
    x::Vector{Float64} # intermediate result/result
    ADMMFlexActor(l::Vector{Float64},
        u::Vector{Float64},
        C::Matrix{Float64},
        d::Vector{Float64},
        S::Vector{Float64}) = new(l, u, C, d, S, Vector{Float64}())
end

function _create_C_and_d(u::Vector{<:Real})
    m = length(u)
    R = 1 + 2*(m-1)
    C = zeros(eltype(u), R, m)
    d = zeros(eltype(u), R)

    for i in 1:length(u)
        C[1, i] = u[i] < 0 ? -1 : 1
    end
    d[1] = sum(abs.(u))

    for j in 1:(m-1)
        
        r1 = 1 + 2*(j-1) + 1
        r2 = r1 + 1

        C[r1, j] = u[j] == 0 || u[m] == 0 ? 0 :  1/u[j]
        C[r1, m] = u[j] == 0 || u[m] == 0 ? 0 : -1/u[m]

        C[r2, j] = u[j] == 0 || u[m] == 0 ? 0 : -1/u[j]
        C[r2, m] = u[j] == 0 || u[m] == 0 ? 0 :  1/u[m]
    end

    return C, d
end

function create_admm_flex_actor_one_to_many(in_capacity::Real, η::Vector{Float64}, S::Union{Nothing,Vector{<:Real}}=nothing)
    tech_capacity = in_capacity .* η

    if isnothing(S)
        S = zeros(length(η))
    end
    l = min.(zeros(length(tech_capacity)), tech_capacity)
    u = max.(tech_capacity, zeros(length(tech_capacity)))
    C, d = _create_C_and_d(tech_capacity)

    return ADMMFlexActor(l, u, C, d, S)
end

function result(actor::ADMMFlexActor)
    return actor.x
end

# Solve the projection / local update via QP: minimize 1/2||x - v||^2 s.t. l <= x <= u, Cx <= d
function _local_update(actor::ADMMFlexActor, v::Vector{Float64}, ρ::Float64)
    m = length(v)
    model = Model(OSQP.Optimizer)
    set_silent(model)
    
    @variable(model, x[1:m])
    
    # admm objective: (ρ/2)||x - v||^2 + S_i·x
    # Note that v = - (correction) in the implementation as a result the equation is based on  (ρ/2)||x + v||^2 + S_i·x
    # transform to standard form Hx^2 - hx
    # in some cases about 100-1000x faster
    H = Diagonal(ones(m) * ρ)
    h = ρ*v

    # + priority cost term: S_i·x
    @objective(model, Min, 0.5 * sum(H[i,i]*x[i]^2 for i=1:m) + sum(h[i]*x[i] for i=1:m) + sum(actor.S[i] * x[i] for i in 1:m))
    #@objective(model, Min, (ρ/2)*sum((x[i] + v[i])^2 + x[i]*actor.S[i] for i in 1:m))
    
    # box constraints
    @constraint(model, [i=1:m], actor.l[i] <= x[i] <= actor.u[i])
    
    # coupling constraints
    @constraint(model, actor.C * x .<= actor.d)

    optimize!(model)

    return value.(x)
end

function on_exchange_message(actor::ADMMFlexActor, carrier::Carrier, message_data::ADMMMessage, meta::Any)
    actor.x = _local_update(actor, message_data.v, message_data.ρ)

    reply_to_other(carrier, ADMMAnswer(actor.x), meta)
end
