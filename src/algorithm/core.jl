export DistributedAlgorithm, on_exchange_message

abstract type DistributedAlgorithm end

function on_exchange_message(algorithm::DistributedAlgorithm, message_data::Any, carrier::Carrier)
    return false
end