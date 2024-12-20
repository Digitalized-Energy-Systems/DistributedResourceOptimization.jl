export DistributedOptimizationRole, MangoCarrier

using Mango

@role struct DistributedOptimizationRole
    algorithm::DistributedAlgorithm
end

function Mango.handle_message(role::DistributedOptimizationRole, message::Any, meta::Any)
    on_exchange_message(role.algorithm, [message], role)
end

struct MangoCarrier <: Carrier
    effective_carrier::DistributedOptimizationRole
end

function send(carrier::MangoCarrier, content::Any, receiver::AgentAddress)
    return send_message(carrier.effective_carrier, content, receiver)
end

function schedule(to_be_scheduled::Function, carrier::MangoCarrier, delay_s::Float64)
    schedule(to_be_scheduled, carrier.effective_carrier, AwaitableTaskData(Timer(delay_s)))
end

function others(carrier::MangoCarrier)
    return topology_neighbors(carrier.effective_carrier)
end