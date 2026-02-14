export DistributedAlgorithm, on_exchange_message, CoordinatedDistributedAlgorithm, start_optimization, Coordinator

"""
    DistributedAlgorithm

An abstract type representing the base for distributed optimization algorithms.
Subtypes should implement specific distributed algorithm logic for resource optimization.
"""
abstract type DistributedAlgorithm end

"""
Supertype for any optimization message. Used to detect whether the message is part of an optimization
"""
abstract type OptimizationMessage end

"""
    on_exchange_message(algorithm::DistributedAlgorithm, carrier::Carrier, message_data::Any, meta::Any)

Handles an incoming exchange message within the distributed algorithm framework.

# Arguments
- `algorithm::DistributedAlgorithm`: The distributed algorithm instance managing the exchange.
- `carrier::Carrier`: The communication carrier responsible for message delivery.
- `message_data::Any`: The data contained in the received message.
- `meta::Any`: Additional metadata associated with the message.

# Description
Processes the received exchange message, updating the algorithm's state or triggering appropriate actions based on the message content and metadata.

# Returns
May return a result or perform side effects depending on the implementation.
"""
function on_exchange_message(algorithm::DistributedAlgorithm, carrier::Carrier, message_data::Any, meta::Any)
    @error algorithm carrier message_data meta
    throw("NotImplementedOrWrongArgumentTypes")
end


"""
    Coordinator

An abstract type representing the coordinator in distributed resource optimization algorithms.
Concrete implementations of this type are responsible for managing and coordinating the optimization process across distributed resources.
"""
abstract type Coordinator end


"""
    start_optimization(coordinator::Coordinator, carrier::Carrier, message_data::Any, meta::Any)

Initiates the optimization process using the provided `coordinator` and `carrier` objects. 
The function takes arbitrary `message_data` and `meta` information to configure or inform the optimization run.

# Arguments
- `coordinator::Coordinator`: The main coordinator responsible for managing the optimization workflow.
- `carrier::Carrier`: The carrier object that facilitates communication or data transfer during optimization.
- `message_data::Any`: Additional data or messages required for the optimization process.
- `meta::Any`: Communication Metadata or supplementary information relevant to the optimization.

# Returns
- The result of the optimization process, which may vary depending on the implementation.

# Notes
- Ensure that `coordinator` and `carrier` are properly initialized before calling this function.
- The types of `message_data` and `meta` are flexible to accommodate various use cases.
"""
function start_optimization(coordinator::Coordinator, carrier::Carrier, message_data::Any, meta::Any)
    throw("NotImplementedOrWrongArgumentTypes")
end


"""
    CoordinatedDistributedAlgorithm

A struct representing the core of a coordinated distributed optimization algorithm.
This type encapsulates the necessary data and methods for coordinating multiple agents
or processes in a distributed resource optimization setting.
"""
struct CoordinatedDistributedAlgorithm 
    distributed_algo::Vector{DistributedAlgorithm}
    coordinator::Coordinator
end

