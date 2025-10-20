## Getting Started

### Using the sharing ADMM with flex actors (e.g. for energy resource optimization) 

You can use DRO in two different ways, using the express style, just executing the distributed optimization routine without embedding it into a larger system. For that two different ways are available, distributed and coordinated optimization.

#### Coordinated (ADMM Sharing with resource actors)

```julia
using DistributedResourceOptimization

flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0, 1.0])

coordinator = create_sharing_target_distance_admm_coordinator()

admm_start = create_admm_start(create_admm_sharing_data([-4, 0, 6], [5,1,1]))

start_coordinated_optimization([flex_actor, flex_actor2, flex_actor3], coordinator, admm_start)
```

#### Distributed (COHDA)

```julia
using DistributedResourceOptimization

actor_one = create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])
actor_two = create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]])

initial_message = create_cohda_start_message([1.2, 2, 3])

wait(start_distributed_optimization([actor_one, actor_two], initial_message))
```

If you need more control, e.g. when integrate the optimization into a larger system we recommend using the carrier system directly, e.g with the built-in carrier:

```julia
using DistributedResourceOptimization

container = ActorContainer()
actor_one = SimpleCarrier(container, create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]]))
actor_two = SimpleCarrier(container, create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]]))

initial_message = create_cohda_start_message([1.2, 2, 3])

wait(send_to_other(actor_one, initial_message, cid(actor_two))) 
```
