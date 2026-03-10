export SimpleCarrier, ActorContainer, cid, start_distributed_optimization, start_coordinated_optimization


using UUIDs

abstract type AbstractSimpleCarrier <: Carrier end

"""
    ActorContainer

    A container to manage multiple `SimpleCarrier`.
"""
mutable struct ActorContainer
    actors::Vector{AbstractSimpleCarrier}
    active_tasks::Threads.Atomic{Int}
    done_event::Base.Event
    function ActorContainer()
        return new(Vector{AbstractSimpleCarrier}(), Threads.Atomic{Int}(0), Base.Event())
    end
end

function register(actor_container::ActorContainer, carrier::AbstractSimpleCarrier)
    push!(actor_container.actors, carrier)
    carrier.aid = length(actor_container.actors)
end

"""
    SimpleCarrier

A concrete implementation of the `Carrier` type representing a simple carrier for distributed resource optimization.
This carrier facilitates communication and scheduling among distributed algorithms within an `ActorContainer`.
"""
mutable struct SimpleCarrier <: AbstractSimpleCarrier
    container::ActorContainer
    actor::Union{<:Coordinator, <:DistributedAlgorithm}
    aid::Real
    uuid_to_handler::Dict{UUID, Function}
    function SimpleCarrier(container::ActorContainer, actor::Union{<:Coordinator, <:DistributedAlgorithm})
        carrier = new(container, actor, -1, Dict{UUID, Function}())
        register(container, carrier)
        return carrier
    end
end

"""
    cid(carrier::SimpleCarrier)
    return the carrier id
"""
function cid(carrier::SimpleCarrier)
    return carrier.aid
end

function Base.wait(carrier::SimpleCarrier, event::EventWithValue)
    wait(event.event)
    return event.value
end

function _dispatch_to(carrier, content, meta)
    if haskey(meta, :message_id) && haskey(carrier.uuid_to_handler, meta[:message_id]) 
        carrier.uuid_to_handler[meta[:message_id]](carrier, content, meta)
    else
        on_exchange_message(carrier.actor, carrier, content, meta)
    end
end

function send_to_other(carrier::SimpleCarrier, content_data::Any, receiver::Real; meta::Dict{Symbol,Any}=Dict{Symbol,Any}())
    other_carrier::Carrier = carrier.container.actors[receiver]
    main_meta = Dict(:sender => carrier.aid, :message_id => uuid4())
    union_meta = merge(main_meta, meta) # important: meta can override main_meta entries
    Threads.atomic_add!(carrier.container.active_tasks, 1)
    return @spawnlog begin
        try
            _dispatch_to(other_carrier, content_data, union_meta)
        finally
            if Threads.atomic_sub!(carrier.container.active_tasks, 1) == 1
                notify(carrier.container.done_event)
            end
        end
    end
end

function reply_to_other(carrier::SimpleCarrier, content_data::Any, meta)
    return send_to_other(carrier, content_data, meta[:sender], meta=merge(meta, Dict(:reply => true)))
end

function send_awaitable(carrier::SimpleCarrier, content_data::Any, receiver::Real; meta::Dict{Symbol,Any}=Dict{Symbol,Any}())
    other_carrier::Carrier = carrier.container.actors[receiver]
    main_meta = Dict(:sender => carrier.aid, :message_id => uuid4())
    union_meta = merge(main_meta, meta) # important: meta can override main_meta entries
    event = EventWithValue(Base.Event(), nothing)
    carrier.uuid_to_handler[union_meta[:message_id]] = function(other_carrier::Carrier, content_data::Any, union_meta::Dict{Symbol,Any})
        event.value = content_data
        notify(event.event)
    end
    @spawnlog begin
        _dispatch_to(other_carrier, content_data, union_meta)
    end
    return event
end

function schedule_using(carrier::SimpleCarrier, to_be_scheduled::Function, delay_s::Float64)
    @spawnlog begin
        sleep(delay_s)
        to_be_scheduled()
    end
end

function others(carrier::SimpleCarrier, id::String)
    return setdiff!(collect(range(1, length(carrier.container.actors))), [cid(carrier)])
end

function get_address(carrier::SimpleCarrier)
    return cid(carrier)
end

"""
    start_distributed_optimization(actors::Vector{<:DistributedAlgorithm}, start_message::Any)

Start a distributed optimization process among the provided `actors` using the given `start_message`.
Return a waitable object that can be used to monitor the progress of the optimization.
"""
function start_distributed_optimization(actors::Vector{<:DistributedAlgorithm}, start_message::Any)
    actor_container = ActorContainer()
    carriers = [SimpleCarrier(actor_container, actor) for actor in actors]
    send_to_other(carriers[1], start_message, cid(carriers[2]))
    return Threads.@spawn wait(actor_container.done_event)
end

"""
    start_coordinated_optimization(actors::Vector{<:DistributedAlgorithm}, coordinator::Coordinator, start_message::Any)

Start a coordinated optimization process among the provided `actors` and a `coordinator` using the given `start_message`.
Return the result of the optimization process. The coordinator manages the overall optimization flow.
""" 
function start_coordinated_optimization(actors::Vector{<:DistributedAlgorithm}, coordinator::Coordinator, start_message::Any)
    actor_container = ActorContainer()
    carriers = [SimpleCarrier(actor_container, actor) for actor in actors]
    coordinator_carrier = SimpleCarrier(actor_container, coordinator)
    return start_optimization(coordinator, coordinator_carrier, start_message, Dict())
end
