
export ConsensusActor, NoConsensusActor, AveragingConsensusAlgorithm, AveragingConsensusMessage, create_averaging_consensus_participant, create_averaging_consensus_start, gradient_term

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

function on_exchange_message(algorithm::AveragingConsensusAlgorithm, carrier::Carrier, message_data::AveragingConsensusMessage, meta::Any)
    #@info "Doing something" algorithm.first_message message_data.k algorithm.k
    if message_data.k >= algorithm.max_iter
        if algorithm.first_message
            # negotiation is over, only new with k=0 is expected
            return
        end
        # finish if iteration count is reached, reset all state data
        algorithm.finish_callback(algorithm, carrier)
        algorithm.first_message = true
        empty!(algorithm.message_queue)
        return
    end

    if algorithm.first_message || message_data.initial
        algorithm.first_message = false
        algorithm.k = 0
        algorithm.λ = ones(length(message_data.λ)) .* algorithm.initial_λ

        for addr in others(carrier, "")
            send_to_other(carrier, AveragingConsensusMessage(algorithm.λ, 0, message_data.data), addr)
        end
    end
    queue = get!(algorithm.message_queue, message_data.k, [])

    push!(queue, message_data)

    if length(queue) == length(others(carrier, "")) || algorithm.k < message_data.k
        avgλ = sum(m.λ for m in queue) ./ length(queue)
        algorithm.λ .+= algorithm.α .* (avgλ .- algorithm.λ) .+ gradient_term(algorithm.actor, algorithm.λ, message_data.data)
        algorithm.k = message_data.k + 1

        delete!(algorithm.message_queue, message_data.k)

        for addr in others(carrier, "")
            send_to_other(carrier, AveragingConsensusMessage(algorithm.λ, algorithm.k, message_data.data), addr)
        end
    end
end

function create_averaging_consensus_participant(finish_callback::Function, consensus_actor::ConsensusActor; initial_λ::Real=10, α::Real=0.3, max_iter::Int=50)
    appl_consensus_actor = isnothing(consensus_actor) ? NoConsensusActor() : consensus_actor

    return AveragingConsensusAlgorithm(finish_callback=finish_callback, initial_λ=initial_λ, α=α, actor=appl_consensus_actor, max_iter=max_iter)
end

"""
    create_averaging_consensus_start(initial_λ::Real, data::Any=nothing) -> AveragingConsensusMessage

Create the initial start message for averaging consensus. `initial_λ` sets the starting
price/signal value (scalar, broadcast to all dimensions), and `data` is any auxiliary
payload forwarded unchanged to each participant's `gradient_term`.
"""
function create_averaging_consensus_start(initial_λ::Real, data::Any=nothing)
    return AveragingConsensusMessage([initial_λ], 0, data, true)
end