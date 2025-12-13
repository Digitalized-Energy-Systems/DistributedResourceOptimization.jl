export Carrier, send_to_other, reply_to_other, send_awaitable, schedule_using, others, get_address

mutable struct EventWithValue
    event::Base.Event
    value::Any
end

function Base.wait(event::EventWithValue)
    wait(event.event)
    return event.value
end

"""
    Carrier

An abstract type representing a generic data/communication carrier in the system.
Concrete subtypes should implement specific carrier behaviors and properties.
"""
abstract type Carrier end

"""
    send_to_other(carrier::Carrier, content_data::Any, receiver::Any)

Sends `content_data` using the specified `carrier` to the given `receiver`.

# Arguments
- `carrier::Carrier`: The carrier object responsible for sending the data.
- `content_data::Any`: The data to be sent.
- `receiver::Any`: The target receiver of the data.

# Returns
- The result of the send operation, which may vary depending on the implementation.

"""
function send_to_other(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented")
end


"""
    reply_to_other(carrier::Carrier, content_data::Any, meta::Any)

Reply using the given `carrier` to another entity, using the provided `content_data` and 
`meta` information.

# Arguments
- `carrier::Carrier`: The carrier object responsible for communication.
- `content_data::Any`: The data to be sent in the reply.
- `meta::Any`: Additional metadata associated with the reply.

# Returns
- The result of the reply operation, depending on the implementation.

# Notes
- The specific behavior depends on the implementation details of the `Carrier` type.
"""
function reply_to_other(carrier::Carrier, content_data::Any, meta::Any)
    throw("NotImplemented")
end


"""
    send_awaitable(carrier::Carrier, content_data::Any, receiver::Any)

Sends an awaitable message using the specified `carrier` to the given `receiver` with the provided `content_data`.

# Arguments
- `carrier::Carrier`: The carrier object responsible for message transmission.
- `content_data::Any`: The data to be sent in the message.
- `receiver::Any`: The target recipient of the message.

# Returns
Returns an awaitable object or handle that can be used to track the completion or response of the sent message.
"""
function send_awaitable(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented $carrier $content_data $receiver")
end

"""
    Base.wait(carrier::Carrier, waitable::Any)

Waits for the specified `waitable` object to become ready or complete within the context of the given `carrier`. 
This function integrates with the `Carrier`'s scheduling or resource management logic to handle asynchronous or blocking operations.

# Arguments
- `carrier::Carrier`: The carrier instance managing the waiting operation.
- `waitable::Any`: The object or resource to wait for. This can be any type that supports waiting semantics.

# Notes
The function blocks until the `waitable` is ready or the operation is complete.
"""
function Base.wait(carrier::Carrier, waitable::Any)
    throw("NotImplemented")
end

"""
    schedule_using(carrier::Carrier, to_be_scheduled::Function, delay_s::Float64)

Schedules the execution of the provided function `to_be_scheduled` using the specified `carrier` after a delay of `delay_s` seconds.

# Arguments
- `carrier::Carrier`: The carrier object responsible for scheduling.
- `to_be_scheduled::Function`: The function to be executed after the delay.
- `delay_s::Float64`: The delay in seconds before executing the function.

# Returns
- Implementation-dependent. Typically, returns a handle or status indicating the scheduled task.
"""
function schedule_using(carrier::Carrier, to_be_scheduled::Function, delay_s::Float64)
    throw("NotImplemented")
end

"""
    others(carrier::Carrier, participant_id::String)

Returns a collection of participants in the given `carrier` excluding the participant with the specified `participant_id`.

# Arguments
- `carrier::Carrier`: The carrier object containing participants.
- `participant_id::String`: The identifier of the participant to exclude.

# Returns
- A collection (e.g., array or set) of participants other than the one with `participant_id`.
"""
function others(carrier::Carrier, participant_id::String)
    throw("NotImplemented")
end

function get_address(carrier::Carrier)
    throw("NotImplemented")
end