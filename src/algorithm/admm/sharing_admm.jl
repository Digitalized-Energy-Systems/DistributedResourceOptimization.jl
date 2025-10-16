export create_sharing_target_distance_admm_coordinator, ADMMSharingGlobalActor, ADMMTargetDistanceObjective, create_admm_sharing_data, create_sharing_admm_coordinator

using JuMP
using OSQP
using LinearAlgebra

struct ADMMTargetDistanceObjective <: ADMMGlobalObjective end

# currently unused
function objective(objective::ADMMTargetDistanceObjective, target::Vector{<:Real}, x, u, z, N)
    m = length(z)
    
    #+ objective(actor.global_objective, input, x, u, N*z, N))
    # quadratic distance
    return sum((target[i] - z[i])^2 for i in 1:m)
end

struct ADMMSharingGlobalActor <: ADMMGlobalActor
    global_objective::ADMMGlobalObjective
end

struct ADMMSharingData
    target::Vector{<:Real}
    priorities::Vector{<:Real}
end

function create_admm_sharing_data(target::Vector{<:Real}, priorities::Union{Nothing,Vector{<:Real}}=nothing)
    if isnothing(priorities)
        priorities = ones(length(target))
    end
    # negative to turn penalty to priority
    return ADMMSharingData(target, -priorities)
end

function create_admm_start(data::ADMMSharingData)
    return ADMMStart(data, length(data.target))
end

function z_update(actor::ADMMSharingGlobalActor, input::ADMMSharingData, x, u, z, ρ, N)
    x_avg = sum(x) ./ length(x)

    m = length(x_avg)

    model = Model(OSQP.Optimizer)
    set_silent(model)
    
    @variable(model, z[1:m])
    @variable(model, d[1:m] >= 0)   # absolute value proxy

    for i in 1:m
        @constraint(model, d[i] >= input.priorities[i] * (N*z[i] - input.target[i]))
        @constraint(model, d[i] >= - input.priorities[i] * (N*z[i] - input.target[i]))
    end

    @objective(model, Min, (N*ρ/2)*sum((z[i] - u[i] - x_avg[i])^2 for i in 1:m)
                + sum(d[i] for i=1:m))
    optimize!(model)
    
    return value.(z)
end

function u_update(actor::ADMMSharingGlobalActor, x, u, z, ρ, N)
    x_avg = sum(x) ./ length(x)
    return u .+ x_avg .- z
end

function init_z(actor::ADMMSharingGlobalActor, n::Int, m::Int)
    return ones(m)
end

function init_u(actor::ADMMSharingGlobalActor, n::Int, m::Int)
    return zeros(m)
end

function actor_correction(actor::ADMMSharingGlobalActor, x, z, u, i)
    x_avg = sum(x) ./ length(x)
    return -x[i] + x_avg - z + u
end

function primal_residual(actor::ADMMSharingGlobalActor, x, z)
    x_avg = sum(x) ./ length(x)
    return maximum(norm.(x_avg .- z))
end

function create_sharing_target_distance_admm_coordinator()
    return ADMMGenericCoordinator(global_actor=ADMMSharingGlobalActor(ADMMTargetDistanceObjective()))
end

"""
    create_sharing_admm_coordinator(objective::ADMMGlobalObjective)

# Arguments
- `objective::ADMMGlobalObjective`: The global objective function to be used in the AD
"""
function create_sharing_admm_coordinator(objective::ADMMGlobalObjective)
    return ADMMGenericCoordinator(global_actor=ADMMSharingGlobalActor(objective))
end
