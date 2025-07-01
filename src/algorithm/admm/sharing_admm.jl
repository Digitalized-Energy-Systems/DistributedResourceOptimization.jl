export create_sharing_target_distance_admm_coordinator, ADMMSharingGlobalActor, ADMMTargetDistanceObjective

using JuMP
using OSQP
using LinearAlgebra

struct ADMMTargetDistanceObjective <: ADMMGlobalObjective end

function objective(objective::ADMMTargetDistanceObjective, target::Vector{<:Real}, x, u, z, N)
    m = length(z)
    
    # quadratic distance
    return sum((target[i] - z[i])^2 for i in 1:m)
end

struct ADMMSharingGlobalActor <: ADMMGlobalActor
    global_objective::ADMMGlobalObjective
end

function z_update(actor::ADMMSharingGlobalActor, input::Any, x, u, z, ρ, N)
    x_avg = sum(x) ./ length(x)

    m = length(x_avg)

    model = Model(OSQP.Optimizer)
    set_silent(model)
    
    @variable(model, z[1:m])
    @objective(model, Min, (N*ρ/2)*sum((z[i] - u[i] - x_avg[i])^2 for i in 1:m) 
                                + objective(actor.global_objective, input, x, u, N*z, N))
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
