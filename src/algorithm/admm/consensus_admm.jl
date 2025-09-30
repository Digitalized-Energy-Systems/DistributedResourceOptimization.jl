export create_consensus_target_reach_admm_coordinator, ADMMConsensusGlobalActor, create_admm_start_consensus


@kwdef struct ADMMConsensusGlobalActor <: ADMMGlobalActor
    α::Int = 100
end

function z_update(actor::ADMMConsensusGlobalActor, input::Vector{<:Real}, x, u, z, ρ, N)
    m = length(z[1])
    S = zeros(m)
    for i in 1:N
        S .+= x[i] .+ u[i]
    end
    δ = (input .- S) ./ (N + actor.α/ρ)
    for i in 1:N
        z[i] = x[i] .+ u[i] .+ δ
    end
    return z
end

function u_update(actor::ADMMConsensusGlobalActor, x, u, z, ρ, N)
    return u + x - z
end

function init_z(actor::ADMMConsensusGlobalActor, n::Int, m::Int)
    return [ones(m) for _ in 1:n]
end

function init_u(actor::ADMMConsensusGlobalActor, n::Int, m::Int)
    return [zeros(m) for _ in 1:n]
end

function actor_correction(actor::ADMMConsensusGlobalActor, x, z, u, i)
    return - z[i] + u[i]
end

function primal_residual(actor::ADMMConsensusGlobalActor, x, z)
    return maximum(norm.(x .- z))
end

function create_consensus_target_reach_admm_coordinator()
    return ADMMGenericCoordinator(global_actor=ADMMConsensusGlobalActor())
end

function create_admm_start_consensus(target::Vector{<:Real})
    return ADMMStart(target, length(target))
end