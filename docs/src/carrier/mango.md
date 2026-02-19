# MangoCarrier

The Mango carrier integrates DRO algorithms with [Mango.jl](https://github.com/OFFIS-DAI/Mango.jl),
a Julia agent framework for realistic distributed system simulation. It enables multi-agent
setups with TCP networking, making it suitable for scenarios that closely mirror real
distributed deployments.

## Prerequisites

Install Mango.jl alongside DRO:

```julia
using Pkg
Pkg.add(["DistributedResourceOptimization", "Mango"])
```

## Core Concepts

DRO integrates with Mango through two *roles* that can be assigned to Mango agents:

| Role | Purpose |
|------|---------|
| [`DistributedOptimizationRole`](@ref) | Wraps a `DistributedAlgorithm` and handles incoming optimization messages |
| [`CoordinatorRole`](@ref) | Wraps a `Coordinator` and handles coordination messages (e.g., for ADMM) |

A role internally creates a [`MangoCarrier`](@ref) that implements DRO's `Carrier` interface,
delegating all message sends to Mango's messaging infrastructure.

## Basic Setup — Distributed Algorithm (COHDA)

```julia
using Mango, DistributedResourceOptimization

# Create a Mango TCP container
container = create_tcp_container("127.0.0.1", 5555)

# Add two agents, each wrapping a COHDA participant
agent_one = add_agent_composed_of(container,
    DistributedOptimizationRole(
        create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])))

agent_two = add_agent_composed_of(container,
    DistributedOptimizationRole(
        create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])))

# Wire agents into a fully-connected topology
auto_assign!(complete_topology(2), container)

start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

# Activate the container and fire the start message
activate(container) do
    send_message(agent_one, start_msg, address(agent_two))
end
```

## Coordinated Algorithm (ADMM)

For algorithms that require a coordinator, add a `CoordinatorRole` to an additional agent:

```julia
using Mango, DistributedResourceOptimization

container = create_tcp_container("127.0.0.1", 5556)

# Participant agents
agent_flex1 = add_agent_composed_of(container,
    DistributedOptimizationRole(create_admm_flex_actor_one_to_many(10.0, [0.1, 0.5, -1.0])))

agent_flex2 = add_agent_composed_of(container,
    DistributedOptimizationRole(create_admm_flex_actor_one_to_many(15.0, [0.1, 0.5, -1.0])))

# Coordinator agent
agent_coord = add_agent_composed_of(container,
    CoordinatorRole(create_sharing_target_distance_admm_coordinator()))

# Topology: participants know each other and the coordinator
auto_assign!(complete_topology(3), container)

start_msg = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))

activate(container) do
    send_message(agent_coord, StartCoordinatedDistributedOptimization(start_msg),
                 address(agent_coord))
end
```

## Topology Management

Mango.jl's `complete_topology(N)` creates a fully-connected graph for `N` agents.
`auto_assign!` distributes the topology across the agents in the container so each agent
knows the addresses of its neighbors.

For custom topologies, manually set the neighbors inside the role after construction, or
use Mango.jl's topology utilities directly.

## Result Notification

When a coordinated optimization finishes, the coordinator broadcasts an
[`OptimizationFinishedMessage`](@ref) to all participants. Subscribe to it in your agent
if you need to collect results:

```julia
using Mango, DistributedResourceOptimization

@agent struct ResultCollector
    results::Vector{Any}
end

@handle_message function collect(agent::ResultCollector, msg::OptimizationFinishedMessage, ::Any)
    push!(agent.results, msg.result)
end
```

## Comparison with SimpleCarrier

| Feature | SimpleCarrier | MangoCarrier |
|---------|--------------|--------------|
| Setup complexity | Minimal | Moderate (Mango agents + container) |
| Communication | In-process tasks | TCP sockets |
| Suitable for | Unit tests, quick experiments | Realistic distributed simulations |
| Parallelism | Julia task scheduler | Mango event loop |
| Topology control | Implicit (all in container) | Explicit (Mango topology API) |

!!! tip "When to Use MangoCarrier"
    Use MangoCarrier when you need realistic network latency simulation, multi-process or
    multi-machine deployment, or integration with a larger Mango.jl agent system.
    For standalone algorithm experiments, [`SimpleCarrier`](simple.md) is simpler and faster.

## See Also

- [`DistributedOptimizationRole`](@ref), [`CoordinatorRole`](@ref), [`MangoCarrier`](@ref)
- [`OptimizationFinishedMessage`](@ref), [`StartCoordinatedDistributedOptimization`](@ref)
- [SimpleCarrier](simple.md) for lightweight in-process simulations
