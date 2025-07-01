export DistributedOptimizationRole, MangoCarrier, CoordinatorRole, StartCoordinatedDistributedOptimization, OptimizationFinishedMessage, wait

using Mango

struct MangoCarrier <: Carrier
    parent::Role
    include_self::Bool
end

struct StartCoordinatedDistributedOptimization 
    input::Any
end

struct OptimizationFinishedMessage 
    result::Any
end

@role struct CoordinatorRole
    coordinator::Coordinator
    carrier::Union{Nothing,MangoCarrier}
    tid::Symbol = :default
    task::Any = nothing
end

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

@role struct DistributedOptimizationRole
    algorithm::DistributedAlgorithm
    carrier::Union{Nothing,MangoCarrier}
    tid::Symbol = :default
end

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

mutable struct EventWithValue
    event::Base.Event
    value::Any
end

function Base.wait(event::EventWithValue)
    wait(event.event)
    return event.value
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

function send_and_wait_for_answers(carrier::MangoCarrier, content_data::Any, receivers::Vector{AgentAddress})
    role = carrier.parent
    event = EventWithValue(Base.Event(), nothing)
    send_and_handle_answers(role, content_data, receivers, optimization_message=true) do _, answers, _
        event.value = answers
        notify(event.event)
    end
    wait(event.event)
    return event.value
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