using Mango
using DistributedOptimization
using Test

@role struct HandleOptimizationResultRole
    got_it::Bool = false
end

function Mango.handle_message(role::HandleOptimizationResultRole, message::OptimizationFinishedMessage, meta::Any)
    role.got_it = true
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActorNegativeEff" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    coordinator = create_sharing_target_distance_admm_coordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    dor3 = DistributedOptimizationRole(flex_actor3, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom, include_self=true)

    handle = HandleOptimizationResultRole()
    handle2 = HandleOptimizationResultRole()
    handle3 = HandleOptimizationResultRole()

    add_agent_composed_of(container, dor, handle)
    c = add_agent_composed_of(container, dor2, handle2)
    ca = add_agent_composed_of(container, coord_role, dor3, handle3)
    
    auto_assign!(complete_topology(3, tid=:custom), container)

    activate(container) do
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start_with_target([2.0, 2.0, 3.0])), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.0, 0.0, 0.0], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.0, 0.0, 0.0], atol=1e-3)
    @test isapprox(flex_actor3.x, [0.0, 0.0, 0.0], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActorNegativeEffPartFullfill" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    coordinator = create_sharing_target_distance_admm_coordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    dor3 = DistributedOptimizationRole(flex_actor3, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom, include_self=true)

    handle = HandleOptimizationResultRole()
    handle2 = HandleOptimizationResultRole()
    handle3 = HandleOptimizationResultRole()

    add_agent_composed_of(container, dor, handle)
    c = add_agent_composed_of(container, dor2, handle2)
    ca = add_agent_composed_of(container, coord_role, dor3, handle3)
    
    auto_assign!(complete_topology(3, tid=:custom), container)

    activate(container) do
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start_with_target([0.2, 1, -2])), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-3)
    @test isapprox(flex_actor3.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActorNegativeEffPartFullfillHetActors" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [1.0, 0.0, -1.0])
    coordinator = create_sharing_target_distance_admm_coordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    dor3 = DistributedOptimizationRole(flex_actor3, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom, include_self=true)

    handle = HandleOptimizationResultRole()
    handle2 = HandleOptimizationResultRole()
    handle3 = HandleOptimizationResultRole()

    add_agent_composed_of(container, dor, handle)
    c = add_agent_composed_of(container, dor2, handle2)
    ca = add_agent_composed_of(container, coord_role, dor3, handle3)
    
    auto_assign!(complete_topology(3, tid=:custom), container)

    activate(container) do
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start_with_target([1.2, 1, -4])), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.1338046305205991, 0.6710353497283177, -1.3420877350612257], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.13380191440490008, 0.6710343387311162, -1.3420863674684713], atol=1e-3)
    @test isapprox(flex_actor3.x, [1.1249597637572557, -1.079012246032314e-6, -1.1249611366933858], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end