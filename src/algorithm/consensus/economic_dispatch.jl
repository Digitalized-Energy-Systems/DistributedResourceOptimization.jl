export LinearCostEconomicDispatchConsensusActor

@kwdef mutable struct LinearCostEconomicDispatchConsensusActor <: ConsensusActor
    cost::Real
    P_max::Real
    ρ::Real = 0.05
    ϵ::Real = 0.1
    P_min::Real = 0
    N_guess::Int = 10
    P::Vector{Float64} = [0]
end

function DistributedResourceOptimization.gradient_term(actor::LinearCostEconomicDispatchConsensusActor, λ::Vector{<:Real}, P_target::Vector{<:Real})
    # linearized inverted quadratic cost function aP¹ + bP minus the target

    actor.P = clamp.((λ .- actor.cost) ./ actor.ϵ, actor.P_min, actor.P_max)
    term =  - actor.ρ .* (actor.P .- P_target ./ actor.N_guess)
    return term
end
