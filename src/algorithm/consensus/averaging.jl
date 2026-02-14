
export ConsensusActor, NoConsensusActor, AveragingConsensusAlgorithm, AveragingConsensusMessage, create_averaging_consensus_participant, gradient_term

abstract type ConsensusActor end

function gradient_term(actor::ConsensusActor, λ::Vector{<:Real}, data::Any)
    return 0
end

mutable struct NoConsensusActor <: ConsensusActor
end

struct AveragingConsensusMessage <: OptimizationMessage
    λ::Vector{Float64}
    k::Int
    data::Any
    initial::Bool
    AveragingConsensusMessage(λ, k, data, initial=false) = new(λ, k, data, initial)
end

struct ConsensusFinishedMessage
    λ::Vector{Float64}
    k::Int
    actor::ConsensusActor
end

@kwdef mutable struct AveragingConsensusAlgorithm <: DistributedAlgorithm
    message_queue::Dict{Int,Vector{AveragingConsensusMessage}} = Dict{Int,Vector{AveragingConsensusMessage}}()
    first_message = true
    k::Int = 0
    max_iter::Int = 50
    λ::Vector{Float64} = [1]

    initial_λ::Real
    α::Real
    actor::ConsensusActor

    finish_callback::Function
end

function on_exchange_message(algorithm_data::AveragingConsensusAlgorithm, carrier::Carrier, message::AveragingConsensusMessage, meta::Any)
    #@info "Doing something" algorithm_data.first_message message.k algorithm_data.k
    if message.k >= algorithm_data.max_iter
        if algorithm_data.first_message 
            # negotiation is over, only new with k=0 is expected
            return
        end
        # finish if iteration count is reached, reset all state data
        algorithm_data.finish_callback(algorithm_data, carrier)
        algorithm_data.first_message = true
        empty!(algorithm_data.message_queue)
        return
    end
    
    if algorithm_data.first_message || message.initial
        algorithm_data.first_message = false
        algorithm_data.k = 0
        algorithm_data.λ = ones(length(message.λ)) .* algorithm_data.initial_λ

        for addr in others(carrier, "")
            send_to_other(carrier, AveragingConsensusMessage(algorithm_data.λ, 0, message.data), addr)
        end
    end
    queue = get!(algorithm_data.message_queue, message.k, [])
    
    push!(queue, message)
    
    if length(queue) == length(others(carrier, "")) || algorithm_data.k < message.k
        avgλ = sum(m.λ for m in queue) ./ length(queue)
        algorithm_data.λ .+= algorithm_data.α .* (avgλ .- algorithm_data.λ) .+ gradient_term(algorithm_data.actor, algorithm_data.λ, message.data)
        algorithm_data.k = message.k + 1

        delete!(algorithm_data.message_queue, message.k)

        for addr in others(carrier, "")
            send_to_other(carrier, AveragingConsensusMessage(algorithm_data.λ, algorithm_data.k, message.data), addr)
        end
    end
end

function create_averaging_consensus_participant(finish_callback::Function, consensus_actor::ConsensusActor; initial_λ::Real=10, α::Real=0.3, max_iter::Int=50) 
    appl_consensus_actor = isnothing(consensus_actor) ? NoConsensusActor() : consensus_actor
    
    return AveragingConsensusAlgorithm(finish_callback=finish_callback, initial_λ=initial_λ, α=α, actor=appl_consensus_actor, max_iter=max_iter)
end