Often a carrier, managing neighbors, communication, message handling, is a big overhead not necessary for simulating the distributed optimization procedure. For this reason DRO.jl implements a simple carrier, which can be used to simplify this part of distributed computing. 

The following example demonstrates how to use this simple carrier, here using the example of COHDA.

```julia
using Mango
using DistributedResourceOptimization

container = ActorContainer()
actor_one = SimpleCarrier(container, create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]]))
actor_two = SimpleCarrier(container, create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]]))

initial_message = create_cohda_start_message([1.2, 2, 3])

send_to_other(actor_one, initial_message, cid(actor_two))

```

To simplify this, it is also possible to completly omit the carrier and container construction, which makes carrier handling to a one-liner using [`start_distributed_optimization`](@ref).

```julia
using Mango
using DistributedResourceOptimization

actor_one = create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])
actor_two = create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]])

initial_message = create_cohda_start_message([1.2, 2, 3])

start_distributed_optimization([actor_one, actor_two], coordinator, initial_message)
```

For coordinated optimization, the method [`start_coordinated_optimization`](@ref) can be used.
