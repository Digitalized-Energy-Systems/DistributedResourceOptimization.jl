using Test

using DistributedOptimization

@kwdef struct TestCarrier <: Carrier
    test_neighbors::Set{Int}
    test_neighbor_messages::Dict{Int,Vector{Any}} = Dict()
end

function DistributedOptimization.send(carrier::TestCarrier, content::Any, receiver::Int)
    message_buffer = get!(carrier.test_neighbor_messages, receiver, Vector())
    push!(message_buffer, content)
end

function DistributedOptimization.schedule(to_be_scheduled::Function, carrier::TestCarrier, delay_s::Float64)
    to_be_scheduled()
end

function DistributedOptimization.others(carrier::TestCarrier)
    return carrier.test_neighbors
end

@testset "Distributed Optimization Tests" begin
    include("cohda_tests.jl")
    include("cohda_local_search_tests.jl")
    include("cohda_mango_tests.jl")
end