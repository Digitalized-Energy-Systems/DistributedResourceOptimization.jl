export DistributedAlgorithm, on_exchange_message, CoordinatedDistributedAlgorithm, start_optimization, Coordinator

abstract type DistributedAlgorithm end

function on_exchange_message(algorithm::DistributedAlgorithm, carrier::Carrier, message_data::Any, meta::Any)
    return false
end

abstract type Coordinator end

function start_optimization(coordinator::Coordinator, carrier::Carrier, message_data::Any, meta::Any)
    return false
end

struct CoordinatedDistributedAlgorithm 
    distributed_algo::Vector{DistributedAlgorithm}
    coordinator::Coordinator
end

