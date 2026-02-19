# Getting Started

## Installation

DRO is registered in the Julia General registry. Open a Julia REPL and run:

```julia
using Pkg
Pkg.add("DistributedResourceOptimization")
```

To use the [Mango.jl carrier](carrier/mango.md) for agent-based simulations, also add:

```julia
Pkg.add("Mango")
```

## Choosing an Algorithm

DRO currently provides three algorithm families:

| Algorithm | Problem type | Coordination |
|-----------|-------------|--------------|
| [ADMM Sharing](algorithms/admm.md) | Continuous, convex resource allocation | Coordinator required |
| [ADMM Consensus](algorithms/admm.md) | Continuous, consensus towards a shared target | Coordinator required |
| [COHDA](algorithms/cohda.md) | Combinatorial schedule selection | Fully distributed |
| [Averaging Consensus](algorithms/consensus.md) | Distributed averaging with gradient terms | Fully distributed |

**Use ADMM** when you have flexible resources with bounded, continuous decision variables and you want to minimize a convex global objective (e.g., match a power target while minimizing deviation cost).

**Use COHDA** when each participant selects exactly one schedule from a discrete set and the goal is to minimize the distance of the combined schedule to a target.

**Use Averaging Consensus** when you need distributed averaging across agents, optionally with local gradient corrections.

## Choosing a Carrier

A *carrier* handles the communication between participants. DRO separates the algorithm from the carrier, so you can switch backends without touching algorithm code.

| Carrier | When to use |
|---------|-------------|
| No carrier (express API) | Quick experiments, single-process simulation |
| [`SimpleCarrier`](carrier/simple.md) | Multi-participant simulation in one process, full control over message flow |
| [`MangoCarrier`](carrier/mango.md) | Realistic distributed simulations with TCP networking via Mango.jl |

## Usage Patterns

### Pattern 1 — Express API (no carrier setup)

The simplest way to run a distributed optimization. DRO wraps everything in a
`SimpleCarrier` internally. Best for quick experiments.

**Distributed algorithms** (COHDA, Averaging Consensus):

```@example gs-cohda
using DistributedResourceOptimization

# Create two participants; each picks one schedule from two choices
actor_one = create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])
actor_two = create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])

# Target combined schedule
start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

# Returns a waitable task; wait for convergence
wait(start_distributed_optimization([actor_one, actor_two], start_msg))
```

**Coordinated algorithms** (ADMM):

```@example gs-admm
using DistributedResourceOptimization

# Three resources, each with capacity and efficiency vector
flex_actor1 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1.0])
flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1.0])
flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0,  1.0])

# Coordinator solves the global z-update step
coordinator = create_sharing_target_distance_admm_coordinator()

# Target power vector [-4, 0, 6] with priorities [5, 1, 1]
start_msg = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))

start_coordinated_optimization([flex_actor1, flex_actor2, flex_actor3], coordinator, start_msg)
```

### Pattern 2 — SimpleCarrier (explicit carrier setup)

Use `SimpleCarrier` when you need direct control: custom message routing, result inspection,
or integration with a larger system.

```@example gs-simple
using DistributedResourceOptimization

# Container holds all carriers and lets them find each other
container = ActorContainer()

actor_one = SimpleCarrier(container, create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]]))
actor_two = SimpleCarrier(container, create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]]))

start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

# Manually kick off the algorithm by sending the start message
wait(send_to_other(actor_one, start_msg, cid(actor_two)))
```

Use `cid(carrier)` to get the integer ID of a carrier within its container.

### Pattern 3 — MangoCarrier (agent-based simulation)

For realistic distributed simulations with TCP networking via [Mango.jl](https://github.com/OFFIS-DAI/Mango.jl).
See the [Mango carrier guide](carrier/mango.md) for full details.

```julia
using Mango, DistributedResourceOptimization

container = create_tcp_container("127.0.0.1", 5555)

agent_one = add_agent_composed_of(container,
    DistributedOptimizationRole(create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])))
agent_two = add_agent_composed_of(container,
    DistributedOptimizationRole(create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])))

auto_assign!(complete_topology(2), container)

start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

activate(container) do
    send_message(agent_one, start_msg, address(agent_two))
end
```

## Next Steps

- See the [Tutorials](tutorials/energy_dispatch.md) for complete, end-to-end examples
- Read the [Algorithm pages](algorithms/admm.md) for mathematical background and parameter guidance
- Check the [How-To Guides](howtos/custom_algorithm.md) to implement your own algorithms or carriers
- Browse the [API Reference](api.md) for all exported symbols
