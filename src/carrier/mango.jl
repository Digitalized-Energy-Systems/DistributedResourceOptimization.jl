export DistributedOptimizationRole, MangoCarrier, CoordinatorRole, StartCoordinatedDistributedOptimization, OptimizationFinishedMessage, wait

using Mango

"""
    MangoCarrier <: Carrier

A concrete implementation of the `Carrier` type representing a mango carrier.
Extend this struct with relevant fields and methods to model the behavior and properties of a mango carrier in the distributed resource optimization context.
"""
struct MangoCarrier <: Carrier
    parent::Role
    include_self::Bool
end

struct StartCoordinatedDistributedOptimization 
    input::Any
end

"""
    OptimizationFinishedMessage

A message struct indicating that an optimization process has completed.
Typically used for signaling the end of an optimization routine in distributed or parallel computation contexts.
"""
struct OptimizationFinishedMessage 
    result::Any
end

"""
    CoordinatorRole

A role struct representing the coordinator in the distributed resource optimization system.
Used to identify and manage coordinator-specific logic and responsibilities within the carrier module.
"""
@role struct CoordinatorRole
    coordinator::Coordinator
    carrier::Union{Nothing,MangoCarrier}
    tid::Symbol = :default
    task::Any = nothing
end

"""
    CoordinatorRole(coordinator::Coordinator; include_self=false, tid::Symbol = :default)

Assigns the coordinator role to the specified `coordinator` object. 

# Arguments
- `coordinator::Coordinator`: The coordinator instance to assign the role to.
- `include_self::Bool=false`: If `true`, includes the coordinator itself in the role assignment.
- `tid::Symbol=:default`: An optional identifier symbol for neighbor lookups.

# Returns
Returns the configured coordinator role.
"""
function CoordinatorRole(coordinator::Coordinator; include_self=false, tid::Symbol = :default)
    role = CoordinatorRole(coordinator, nothing, tid=tid)
    role.carrier = MangoCarrier(role, include_self)
    return role
end

function Mango.handle_message(role::CoordinatorRole, message::StartCoordinatedDistributedOptimization, meta::Any)
    role.task = schedule(role, InstantTaskData()) do
        x = start_optimization(role.coordinator, role.carrier, message.input, meta)

        for (i, addr) in enumerate(others(role.carrier, "participant"))
            send_message(role, OptimizationFinishedMessage(x[i]), addr)
        end
    end
end


"""
    DistributedOptimizationRole

A role struct used to define distributed optimization responsibilities within the system.
Attach this role to entities that participate in distributed resource optimization processes.
"""
@role struct DistributedOptimizationRole
    algorithm::DistributedAlgorithm
    carrier::Union{Nothing,MangoCarrier}
    tid::Symbol = :default
end

"""
    DistributedOptimizationRole(algorithm::DistributedAlgorithm; tid::Symbol = :default)

Creates and returns a distributed optimization role using the specified `algorithm`. 
An optional identifier `tid` can be provided, defaulting to `:default`.

# Arguments
- `algorithm::DistributedAlgorithm`: The distributed optimization algorithm to be used.
- `tid::Symbol`: (Optional) Identifier for the neighbor lookup. Defaults to `:default`.

# Returns
A distributed optimization role configured with the given algorithm and an identifier
to specify the addresses of other participants.
"""
function DistributedOptimizationRole(algorithm::DistributedAlgorithm; tid::Symbol = :default)
    role = DistributedOptimizationRole(algorithm, nothing, tid=tid)
    role.carrier = MangoCarrier(role, false)
    return role
end

function Mango.handle_message(role::DistributedOptimizationRole, message::Any, meta::Any)
    if haskey(meta, "optimization_message") && meta["optimization_message"]
        on_exchange_message(role.algorithm, role.carrier, message, meta)
    end
end

function Base.wait(carrier::MangoCarrier, waitable::Any)
    wait(waitable)
end

function send_to_other(carrier::MangoCarrier, content::Any, receiver::AgentAddress)
    return send_message(carrier.parent, content, receiver, optimization_message=true)
end

function Base.wait(carrier::MangoCarrier, event::EventWithValue)
    wait(carrier.parent.context.agent.scheduler, event.event)
    return event.value
end

function send_awaitable(carrier::MangoCarrier, content::Any, receiver::AgentAddress)
    event = EventWithValue(Base.Event(), nothing)
    send_and_handle_answer(carrier.parent, content, receiver, optimization_message=true) do _, answer,_
        event.value = answer
        notify(carrier.parent.context.agent.scheduler, event.event)
    end
    return event
end

function reply_to_other(carrier::MangoCarrier, content_data::Any, meta::Any)
    reply_to(carrier.parent, content_data, meta)
end

function schedule_using(carrier::MangoCarrier, to_be_scheduled::Function, delay_s::Float64)
    schedule(carrier.parent, to_be_scheduled, AwaitableTaskData(Timer(delay_s)))
end

function others(carrier::MangoCarrier, participant_id::String)
    if carrier.include_self
        return [topology_neighbors(carrier.parent, tid=carrier.parent.tid); [address(carrier.parent)]]
    else
        return topology_neighbors(carrier.parent, tid=carrier.parent.tid)
    end
end

function get_address(carrier::MangoCarrier)
    return address(carrier.parent)
end