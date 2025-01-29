export DistributedOptimizationRole, MangoCarrier

using Mango

struct MangoCarrier <: Carrier
    parent::Role
end

@role struct DistributedOptimizationRole
    algorithm::DistributedAlgorithm
    carrier::Union{Nothing,MangoCarrier}
end

function DistributedOptimizationRole(algorithm::DistributedAlgorithm)
    role = DistributedOptimizationRole(algorithm, nothing)
    role.carrier = MangoCarrier(role)
    return role
end

function Mango.handle_message(role::DistributedOptimizationRole, message::Any, meta::Any)
    on_exchange_message(role.algorithm, [message], role)
end

function send_using(carrier::MangoCarrier, content::Any, receiver::AgentAddress)
    return send_message(carrier.parent, content, receiver)
end

function schedule_using(to_be_scheduled::Function, carrier::MangoCarrier, delay_s::Float64)
    schedule(to_be_scheduled, carrier.parent, AwaitableTaskData(Timer(delay_s)))
end

function others(carrier::MangoCarrier, participant_id::String)
    return topology_neighbors(carrier.parent)
end