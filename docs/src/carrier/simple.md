# SimpleCarrier

`SimpleCarrier` is DRO's built-in, lightweight carrier. It runs all participants as
Julia tasks within a single process, with no network or serialization overhead. It is
the recommended choice for prototyping, testing, and single-machine simulations.

## Core Types

### `ActorContainer`

An `ActorContainer` holds all `SimpleCarrier` instances and lets them find each other
by numeric ID. Create one container per simulation:

```@example simple-sc
using DistributedResourceOptimization

container = ActorContainer()
```

### `SimpleCarrier`

Wraps an algorithm (or coordinator) and registers it with a container:

```@example simple-sc
carrier_one = SimpleCarrier(container, create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]]))
carrier_two = SimpleCarrier(container, create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]]))
```

Each carrier is automatically assigned an integer ID when it registers. Retrieve it with
[`cid`](@ref):

```@example simple-sc
id_one = cid(carrier_one)   # => 1
id_two = cid(carrier_two)   # => 2
```

## Sending Messages

Use [`send_to_other`](@ref) to dispatch a message to another carrier in the same container.
The message is delivered asynchronously (spawned as a Julia task):

```@example simple-sc
start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

# Returns a task; wait for it to complete
wait(send_to_other(carrier_one, start_msg, cid(carrier_two)))
```

## Express API

For quick experiments you can skip creating the container and carriers yourself.
[`start_distributed_optimization`](@ref) wraps everything in a single call:

```@example simple-express-cohda
using DistributedResourceOptimization

actor_one = create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])
actor_two = create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])

start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

wait(start_distributed_optimization([actor_one, actor_two], start_msg))
```

For coordinated algorithms (e.g., ADMM), use [`start_coordinated_optimization`](@ref):

```@example simple-express-admm
using DistributedResourceOptimization

flex1 = create_admm_flex_actor_one_to_many(10.0, [0.1, 0.5, -1.0])
flex2 = create_admm_flex_actor_one_to_many(15.0, [0.1, 0.5, -1.0])
flex3 = create_admm_flex_actor_one_to_many(10.0, [-1.0, 0.0, 1.0])

coordinator = create_sharing_target_distance_admm_coordinator()
start_msg   = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))

start_coordinated_optimization([flex1, flex2, flex3], coordinator, start_msg)
```

## Awaitable Messages

If a participant needs a response from another before continuing, use
[`send_awaitable`](@ref), which returns an `EventWithValue` that can be waited on:

```julia
event = send_awaitable(carrier_one, my_request, cid(carrier_two))
response = wait(carrier_one, event)
```

## Scheduling Delayed Calls

To execute a function after a delay (without blocking the caller), use
[`schedule_using`](@ref):

```julia
schedule_using(carrier_one, () -> println("fired after 1 s"), 1.0)
```

!!! note "Thread Safety"
    All message dispatches are wrapped in [`@spawnlog`], a macro that spawns a Julia task
    and logs any exceptions with thread ID and backtrace. Make sure your Julia runtime has
    multiple threads available (`julia -t auto`) if you want true parallelism.

## See Also

- [`SimpleCarrier`](@ref), [`ActorContainer`](@ref), [`cid`](@ref)
- [`start_distributed_optimization`](@ref), [`start_coordinated_optimization`](@ref)
- [`send_to_other`](@ref), [`send_awaitable`](@ref), [`schedule_using`](@ref)
- [MangoCarrier](mango.md) for agent-based simulations with TCP networking
