using Test

using DistributedResourceOptimization

@kwdef struct TestCarrier <: Carrier
    test_neighbors::Set{Int}
    test_neighbor_messages::Dict{Int,Vector{Any}} = Dict()
end

function DistributedResourceOptimization.send(carrier::TestCarrier, content::Any, receiver::Int)
    message_buffer = get!(carrier.test_neighbor_messages, receiver, Vector())
    push!(message_buffer, content)
end

function DistributedResourceOptimization.schedule(to_be_scheduled::Function, carrier::TestCarrier, delay_s::Float64)
    to_be_scheduled()
end

function DistributedResourceOptimization.others(carrier::TestCarrier, participant_id::String)
    return carrier.test_neighbors
end

@testset "Distributed Optimization Tests" begin
    include("cohda/cohda_tests.jl")
    include("cohda/cohda_local_search_tests.jl")
    include("cohda/cohda_mango_tests.jl")
    include("admm/consensus_admm_tests.jl")
    include("admm/sharing_admm_tests.jl")
end