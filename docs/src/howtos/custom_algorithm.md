# How To: Implement a Custom Algorithm

DRO's algorithm abstraction has a single required method. Implementing it lets your
algorithm participate in any carrier — `SimpleCarrier`, `MangoCarrier`, or one you write
yourself.

## The Interface

All distributed algorithms extend `DistributedAlgorithm` and implement
[`on_exchange_message`](@ref):

```julia
abstract type DistributedAlgorithm end

function on_exchange_message(
    ::DistributedAlgorithm,
    ::Carrier,
    ::Any,   # message_data
    ::Any,   # meta
)
    # Your logic here
end
```

| Argument | Type | Description |
|----------|------|-------------|
| `algorithm` | Your concrete subtype | Holds all algorithm state |
| `carrier` | `Carrier` | Use this to send replies or schedule callbacks |
| `message_data` | Any | The deserialized message payload |
| `meta` | Any | Transport metadata (e.g., `Dict(:sender => id)` for `SimpleCarrier`) |

## Step-by-Step Example — Echo Algorithm

As a minimal example, here is an algorithm that counts how many messages it receives and
echoes each one back to the sender.

### 1. Define the State Struct

```julia
using DistributedResourceOptimization

mutable struct EchoAlgorithm <: DistributedAlgorithm
    count::Int
    EchoAlgorithm() = new(0)
end
```

### 2. Define a Message Type

Subtyping `OptimizationMessage` lets DRO identify your messages as part of an
optimization session (required for correct dispatch through the carrier):

```julia
struct EchoMessage <: OptimizationMessage
    payload::String
end
```

### 3. Implement `on_exchange_message`

```julia
function on_exchange_message(
    algo::EchoAlgorithm,
    carrier::Carrier,
    msg::EchoMessage,
    meta::Any,
)
    algo.count += 1
    @info "Received message #$(algo.count): $(msg.payload)"

    # Reply to sender with a confirmation
    reply_to_other(carrier, EchoMessage("ACK: $(msg.payload)"), meta)
end
```

### 4. Run it

```julia
using DistributedResourceOptimization

algo1 = EchoAlgorithm()
algo2 = EchoAlgorithm()

container = ActorContainer()
carrier1  = SimpleCarrier(container, algo1)
carrier2  = SimpleCarrier(container, algo2)

wait(send_to_other(carrier1, EchoMessage("hello"), cid(carrier2)))
```

## Coordinated Algorithms

For algorithms that require a central coordinator (like ADMM), implement a `Coordinator`
subtype alongside your `DistributedAlgorithm`:

```julia
abstract type Coordinator end

function start_optimization(
    ::Coordinator,
    ::Carrier,
    ::Any,   # message_data
    ::Any,   # meta
)
    # Kick off the coordinated optimization
end
```

The coordinator is wrapped in its own `SimpleCarrier` (or Mango agent) and is the entry
point for [`start_coordinated_optimization`](@ref).

## Practical Tips

**Keep algorithm state in the struct.** Since each `SimpleCarrier` runs in separate Julia
tasks, mutable fields of your algorithm struct are effectively actor state. Julia's task
scheduler handles concurrent access within a single carrier.

**Use `send_awaitable` for request/reply patterns.** If your algorithm needs a response
before proceeding (e.g., a parallel x-update phase), use `send_awaitable` + `wait`:

```julia
event = send_awaitable(carrier, MyRequest(data), target_id)
response = wait(carrier, event)
```

**Schedule callbacks with `schedule_using`.** To trigger an action after a delay without
blocking the current message handler:

```julia
schedule_using(carrier, () -> my_timeout_action(algo, carrier), 5.0)
```

**Termination.** DRO has no built-in termination protocol — implement convergence
detection inside your `on_exchange_message` and simply stop sending messages when done.

## See Also

- [`DistributedAlgorithm`](@ref), [`on_exchange_message`](@ref)
- [`Coordinator`](@ref), [`start_optimization`](@ref)
- [How To: Implement a Custom Carrier](custom_carrier.md)
- [COHDA source](https://github.com/Digitalized-Energy-Systems/DistributedResourceOptimization.jl/blob/main/src/algorithm/heuristic/cohda/core.jl)
  for a real-world reference implementation
