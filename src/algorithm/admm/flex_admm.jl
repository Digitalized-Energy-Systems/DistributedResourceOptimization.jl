export ADMMFlexAnswer, ADMMFlexMessage, ADMMFlexActor, ADMMFlexCoordinator, create_admm_flex_actor_one_to_many, result

using Distributed
using LinearAlgebra
using JuMP
using OSQP

struct ADMMFlexMessage 
    v::Vector{Float64}
    ρ::Float64
end

struct ADMMFlexAnswer 
    x::Vector{Float64}
end

mutable struct ADMMFlexActor <: DistributedAlgorithm
    l::Vector{Float64} # lower bounds
    u::Vector{Float64} # upper bounds
    C::Matrix{Float64} # coupling matrix
    d::Vector{Float64} # coupling RHS
    x::Vector{Float64} # intermediate result/result
    ADMMFlexActor(l::Vector{Float64},
        u::Vector{Float64},
        C::Matrix{Float64},
        d::Vector{Float64}) = new(l, u, C, d, Vector{Float64}())
end

function _create_C_and_d(u::Vector{<:Real})
    m = length(u)
    R = 1 + 2*(m-1)
    C = zeros(eltype(u), R, m)
    d = zeros(eltype(u), R)

    C[1, :] .= 1
    d[1] = sum(u)

    for j in 1:(m-1)
      r1 = 1 + 2*(j-1) + 1
      r2 = r1 + 1

      C[r1, j] =  1/u[j]
      C[r1, m] = -1/u[m]

      C[r2, j] = -1/u[j]
      C[r2, m] =  1/u[m]
    end

    return C, d
end

function create_admm_flex_actor_one_to_many(in_capacity::Real, η::Vector{Float64})
    tech_capacity = in_capacity .* η

    l = zeros(length(tech_capacity))
    u = tech_capacity
    C, d = _create_C_and_d(tech_capacity)

    return ADMMFlexActor(l, u, C, d)
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
    # objective: (ρ/2)||x - v||^2
    @objective(model, Min, (ρ/2)*sum((x[i] - v[i])^2 for i in 1:m))
    # box constraints
    @constraint(model, [i=1:m], actor.l[i] <= x[i] <= actor.u[i])
    
    # coupling constraints
    @constraint(model, actor.C * x .<= actor.d)

    optimize!(model)
    return value.(x)
end

function on_exchange_message(actor::ADMMFlexActor, carrier::Carrier, message_data::ADMMFlexMessage, meta::Any)
    actor.x = _local_update(actor, message_data.v, message_data.ρ)
    reply_to_other(carrier, ADMMFlexAnswer(actor.x), meta)
end

@kwdef struct ADMMFlexCoordinator <: Coordinator
    T::Vector{Float64}
    ρ::Float64 = 1.0 
    max_iters::Int64 = 100
    slack_penalty::Int64 = 100
    abs_tol::Float64 = 1e-4
    rel_tol::Float64 = 1e-3
end

# ADMM solver
function _admm_flex(admm::ADMMFlexCoordinator, carrier::Carrier)
    T = admm.T
    ρ = admm.ρ
    max_iters = admm.max_iters
    slack_penalty = admm.slack_penalty
    abs_tol = admm.abs_tol
    rel_tol = admm.rel_tol
    n = length(others(carrier, "coordinator"))
    m = length(T)

    # Initialize
    x = [zeros(m) for i in 1:n]
    z = [T ./ n for i in 1:n]
    u = [zeros(m) for i in 1:n]

    for k in 1:max_iters
        # 1. Local x-updates (in parallel)
        awaitables = []
        # send all async and get awaitable
        for (i,addr) in enumerate(others(carrier, "c"))
            push!(awaitables, send_awaitable(carrier, ADMMFlexMessage(z[i] - u[i], ρ), addr))
        end
        # await all awaitables and update x
        for (i,awaitable) in enumerate(awaitables)
            x[i] = wait(awaitable).x
        end
        # 2. Global z-update
        S = zeros(m)
        for i in 1:n
            S .+= x[i] .+ u[i]
        end
        α = slack_penalty
        δ = (T .- S) ./ (n + α/ρ)
        z_old = deepcopy(z)
        for i in 1:n
            z[i] = x[i] .+ u[i] .+ δ
        end
        # 3. Dual u-update
        for i in 1:n
            u[i] .+= x[i] .- z[i]
        end
        # 4. Check convergence
        # primal residual: max over i of ||x_i - z_i||
        r_norm = maximum(norm.(x .- z))
        # dual residual: ρ * max over i of ||z_i - z_old_i||
        s_norm = ρ * maximum(norm.(z .- z_old))
        # tolerances
        ϵ_pri = sqrt(m*n)*abs_tol + rel_tol*max(maximum(norm.(x)), maximum(norm.(z)))
        ϵ_dual = sqrt(m*n)*abs_tol + rel_tol*maximum(norm.(u))
        if r_norm < ϵ_pri && s_norm < ϵ_dual
            @debug "Converged in $k iterations."
            break
        end
        if k == max_iters
            @warn "Reached max iterations ($max_iters) without full convergence."
        end
    end
    return x, z, u
end

function start_optimization(coordinator::ADMMFlexCoordinator, carrier::Carrier, message_data::Any, meta::Any)
    x,_,_ = _admm_flex(coordinator, carrier)
    return x
end
