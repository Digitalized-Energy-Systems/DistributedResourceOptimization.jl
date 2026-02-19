# How To: Implement a Custom Carrier

A *carrier* is the communication layer that delivers messages between algorithm
participants. DRO ships with `SimpleCarrier` (in-process) and `MangoCarrier` (Mango.jl
TCP). This guide shows how to write your own.

## The Interface

All carriers extend `Carrier` and implement six functions:

```julia
abstract type Carrier end

# Send a message to another participant (fire-and-forget)
send_to_other(::Carrier, content::Any, receiver::Any)

# Reply to the sender of an incoming message
reply_to_other(::Carrier, content::Any, meta::Any)

# Send a message and return an awaitable handle
send_awaitable(::Carrier, content::Any, receiver::Any)

# Block until an awaitable handle completes; return its value
Base.wait(::Carrier, waitable::Any)

# Schedule a zero-argument function after `delay_s` seconds
schedule_using(::Carrier, f::Function, delay_s::Float64)

# Return IDs of all other participants (excluding self)
others(::Carrier, self_id::String)
```

You do not need to implement `get_address` unless your carrier is used with parts of the
codebase that call it explicitly.

## Step-by-Step Example — Logging Carrier

Here is a carrier that wraps `SimpleCarrier` and logs every message send. It is a useful
debugging wrapper for any algorithm.

### 1. Define the Struct

```julia
using DistributedResourceOptimization

struct LoggingCarrier <: Carrier
    inner::SimpleCarrier
end
```

### 2. Delegate and Log

Implement each required function by delegating to the inner carrier:

```julia
function send_to_other(c::LoggingCarrier, content::Any, receiver::Any)
    @info "[LoggingCarrier] send → $receiver: $(typeof(content))"
    send_to_other(c.inner, content, receiver)
end

function reply_to_other(c::LoggingCarrier, content::Any, meta::Any)
    sender = get(meta, :sender, "?")
    @info "[LoggingCarrier] reply → $sender: $(typeof(content))"
    reply_to_other(c.inner, content, meta)
end

function send_awaitable(c::LoggingCarrier, content::Any, receiver::Any)
    @info "[LoggingCarrier] send_awaitable → $receiver: $(typeof(content))"
    send_awaitable(c.inner, content, receiver)
end

function Base.wait(c::LoggingCarrier, waitable::Any)
    wait(c.inner, waitable)
end

function schedule_using(c::LoggingCarrier, f::Function, delay_s::Float64)
    schedule_using(c.inner, f, delay_s)
end

function others(c::LoggingCarrier, self_id::String)
    others(c.inner, self_id)
end
```

### 3. Wire It Up

Because algorithm dispatch happens through `on_exchange_message(algo, carrier, msg, meta)`,
you need to make sure your carrier is passed there. The easiest way is to subclass the
relevant role or override dispatch — but for simple wrapping, you can construct
`LoggingCarrier` around an existing `SimpleCarrier`:

```julia
using DistributedResourceOptimization

container = ActorContainer()

algo1 = create_cohda_participant(1, [[0.0, 1.0], [1.0, 2.0]])
algo2 = create_cohda_participant(2, [[0.0, 1.0], [1.0, 2.0]])

sc1 = SimpleCarrier(container, algo1)
sc2 = SimpleCarrier(container, algo2)

lc1 = LoggingCarrier(sc1)   # wraps carrier 1 for logging

start_msg = create_cohda_start_message([1.0, 2.0])

wait(send_to_other(lc1, start_msg, cid(sc2)))
```

## Building a Carrier from Scratch

If you want a completely independent carrier (e.g., backed by ZeroMQ or HTTP), follow
these principles:

1. **Message dispatch** — When a message arrives (from the network, a queue, etc.), call
   `on_exchange_message(algorithm, your_carrier, message_data, meta)`.

2. **Metadata** — The `meta` dict passed to `on_exchange_message` must contain at least
   `:sender` so that `reply_to_other` can route the response back. Additional keys are
   carrier-specific.

3. **Awaitable pattern** — `send_awaitable` must return something that `Base.wait` can
   block on. The simplest implementation uses `EventWithValue`:

   ```julia
   function send_awaitable(c::MyCarrier, content::Any, receiver::Any)
       event = EventWithValue(Base.Event(), nothing)
       # store event keyed by a message ID; resolve it when the reply arrives
       c.pending[my_id] = event
       _dispatch_message(c, content, receiver, my_id)
       return event
   end

   function Base.wait(c::MyCarrier, ev::EventWithValue)
       wait(ev.event)
       return ev.value
   end
   ```

4. **`others`** — Return a collection of addresses/IDs that the algorithm can pass back
   to `send_to_other`. The type is up to you; just be consistent.

## Checklist

- [ ] Subtype `Carrier`
- [ ] Implement `send_to_other`
- [ ] Implement `reply_to_other`
- [ ] Implement `send_awaitable` returning something `Base.wait`-able
- [ ] Implement `Base.wait(carrier, waitable)`
- [ ] Implement `schedule_using`
- [ ] Implement `others`
- [ ] Call `on_exchange_message` when an inbound message arrives

## See Also

- [`Carrier`](@ref), [`send_to_other`](@ref), [`reply_to_other`](@ref)
- [`send_awaitable`](@ref), [`schedule_using`](@ref), [`others`](@ref)
- [`SimpleCarrier`](@ref) — reference implementation in `src/carrier/simple.jl`
- [How To: Implement a Custom Algorithm](custom_algorithm.md)
