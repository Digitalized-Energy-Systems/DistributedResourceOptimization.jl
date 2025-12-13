using Mango
using DistributedResourceOptimization
using Test

@testset "TestAveragingConsensusWithSC" begin
    finished = false
    # describe quadratic cost function with quasi-linear behavior
    actor_one = create_averaging_consensus_participant(LinearCostEconomicDispatchConsensusActor(cost=10, P_max=30, N_guess=3), max_iter=100) do _,_
        finished = true        
    end
    actor_two = create_averaging_consensus_participant(LinearCostEconomicDispatchConsensusActor(cost=15, P_max=10, N_guess=3), max_iter=100) do _,_
    end
    actor_three = create_averaging_consensus_participant(LinearCostEconomicDispatchConsensusActor(cost=12, P_max=22, N_guess=3), max_iter=100) do _,_
    end

    P_target = [10, 30, 40, 45, 60, 10]
    initial_message = AveragingConsensusMessage([10] .* ones(length(P_target)), 0, P_target)

    wait(start_distributed_optimization([actor_one, actor_two, actor_three], initial_message))

    wait(Threads.@spawn begin
        while actor_one.k < 50
            sleep(0.01)
        end
    end)

    @test isapprox(actor_one.λ, actor_two.λ, atol=1)
    @test finished
end
