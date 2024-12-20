export Carrier, send, schedule, others

abstract type Carrier end

function send(carrier::Carrier, content_data::Any, receiver::Any)
    throw("NotImplemented")
end
function schedule(to_be_scheduled::Function, carrier::Carrier, delay_s::Float64)
    throw("NotImplemented")
end
function others(carrier::Carrier)
    throw("NotImplemented")
end