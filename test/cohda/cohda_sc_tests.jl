using Mango
using DistributedResourceOptimization
using Test

@testset "TestCOHDAWithSimpleCarrier" begin

    container = ActorContainer()
    actor_one = SimpleCarrier(container, create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]]))
    actor_two = SimpleCarrier(container, create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]]))

    initial_message = create_cohda_start_message([1.2, 2, 3])

    wait(send_to_other(actor_one, initial_message, cid(actor_two)))

    @test actor_one.actor.memory.solution_candidate.perf == -3.2
end

@testset "TestCOHDAWithSimpleCarrierExpress" begin

    actor_one = create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])
    actor_two = create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]])

    initial_message = create_cohda_start_message([1.2, 2, 3])

    wait(start_distributed_optimization([actor_one, actor_two], initial_message))

    @test actor_one.memory.solution_candidate.perf == -3.2
end