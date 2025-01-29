export Carrier, send_using, schedule_using, others

abstract type Carrier end

function send_using(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented")
end
function schedule_using(to_be_scheduled::Function, carrier::Carrier, delay_s::Float64)
    throw("NotImplemented")
end
function others(carrier::Carrier, participant_id::String)
    throw("NotImplemented")
end