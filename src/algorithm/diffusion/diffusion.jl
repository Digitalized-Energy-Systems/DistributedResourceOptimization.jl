export DiffusionActor, NoDiffusionActor, DiffusionAlgorithm, DiffusionMessage, create_diffusion_participant, create_diffusion_start, gradient_term

abstract type DiffusionActor end

function gradient_term(actor::DiffusionActor, λ::Vector{<:Real}, data::Any)
    return 0
end

mutable struct NoDiffusionActor <: DiffusionActor
end

struct DiffusionMessage <: OptimizationMessage
    φ::Vector{Float64}
    k::Int
    data::Any
    initial::Bool
    DiffusionMessage(φ, k, data, initial=false) = new(φ, k, data, initial)
end

@kwdef mutable struct DiffusionAlgorithm <: DistributedAlgorithm
    message_queue::Dict{Int,Vector{DiffusionMessage}} = Dict{Int,Vector{DiffusionMessage}}()
    first_message = true
    k::Int = 0

    max_iter::Int
    λ::Vector{Float64} = [1.0]
    φ::Vector{Float64} = [1.0]

    initial_λ::Real
    ε::Real  # Step size for gradient adaptation
    actor::DiffusionActor
    horizon::Int  # Number of time steps in the schedule

    finish_callback::Function
end

function on_exchange_message(algorithm::DiffusionAlgorithm, carrier::Carrier, message::DiffusionMessage, meta::Any)
    if message.k >= algorithm.max_iter
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
    
    if algorithm.first_message || message.initial
        algorithm.first_message = false
        algorithm.k = 0

        # Initialize λ for full schedule
        T = algorithm.horizon
        # Fix: Broadcast scalar initial_λ to vector of length T
        algorithm.λ = ones(length(message.φ)) .* algorithm.initial_λ


        # Adaptation for φ⁰ (compute optimal power for full schedule)
        ∇J = gradient_term(algorithm.actor, algorithm.λ, message.data)
        algorithm.φ = algorithm.λ .- algorithm.ε .* ∇J

        # Send φ to neighbors
        for addr in others(carrier, "")
            send_to_other(carrier,
                DiffusionMessage(algorithm.φ, 0, message.data),
                addr
            )
        end
    end
    
    queue = get!(algorithm.message_queue, message.k, [])
    push!(queue, message)

    # Check if all messages received for this iteration
    if length(queue) == length(others(carrier, ""))


        # COMBINATION - average of all φ values
        n = length(queue) + 1
        λ_new = copy(algorithm.φ)

        for m in queue
            λ_new .+= m.φ
        end

        algorithm.λ = λ_new ./ n

        delete!(algorithm.message_queue, message.k)


        # ADAPTATION - compute optimal power for full schedule
        ∇J = gradient_term(algorithm.actor, algorithm.λ, message.data)
        algorithm.φ = algorithm.λ .- algorithm.ε .* ∇J


        # println("λ=", algorithm.λ, " gradient=", ∇J)

        algorithm.k += 1


        # SEND φ for next iteration (or completion)
        for addr in others(carrier, "")
            send_to_other(carrier, DiffusionMessage(algorithm.φ, algorithm.k, message.data), addr)
        end
    end

end


function create_diffusion_participant(finish_callback::Function, diffusion_actor::DiffusionActor; initial_λ::Real=10.0, ε::Real=0.1, max_iter::Int=300, horizon::Int=24)
    appl_diffusion_actor = isnothing(diffusion_actor) ? NoDiffusionActor() : diffusion_actor

    return DiffusionAlgorithm(finish_callback=finish_callback, initial_λ=initial_λ, ε=ε, actor=appl_diffusion_actor, max_iter=max_iter, horizon=horizon)
end

"""
    create_diffusion_start(initial_λ::Real, data::Any=nothing) -> DiffusionMessage

Create the initial start message for diffusion algorithm. `initial_λ` sets the starting
incremental cost value (scalar, broadcast to all dimensions), and `data` is any auxiliary
payload forwarded unchanged to each participant's `gradient_term`.
"""
function create_diffusion_start(initial_λ::Real, data::Any=nothing)
    return DiffusionMessage([initial_λ], 0, data, true)
end
