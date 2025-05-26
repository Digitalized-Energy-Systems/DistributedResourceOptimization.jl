export Carrier, send_to_other, reply_to_other, send_and_wait_for_answers, send_awaitable, schedule_using, others

abstract type Carrier end

function send_to_other(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented")
end
function reply_to_other(carrier::Carrier, content_data::Any, meta::Any)
    throw("NotImplemented")
end
function send_and_wait_for_answers(carrier::Carrier, content_data::Any, receivers::Any)
    throw("NotImplemented")
end
function send_awaitable(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented $carrier $content_data $receiver")
end
function Base.wait(carrier::Carrier, waitable::Any)
    throw("NotImplemented")
end
function schedule_using(carrier::Carrier, to_be_scheduled::Function, delay_s::Float64)
    throw("NotImplemented")
end
function others(carrier::Carrier, participant_id::String)
    throw("NotImplemented")
end