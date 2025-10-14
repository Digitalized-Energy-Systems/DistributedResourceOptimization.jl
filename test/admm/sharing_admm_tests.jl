using Mango
using DistributedResourceOptimization
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([2.0, 2.0, 3.0]))), address(ca)))
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([0.2, 1, -2]))), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-2)
    @test isapprox(flex_actor2.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-2)
    @test isapprox(flex_actor3.x, [0.06666795239195517, 0.3333332205122851, -0.6666666349151213], atol=1e-2)
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([1.2, 1, -4]))), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.1551348309982447, 0.7764857848417002, -1.5529580879935843], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.1551322355095896, 0.7764795912324005, -1.5529455908199763], atol=1e-3)
    @test isapprox(flex_actor3.x, [0.8928358745473691, -1.2344094570466974e-6, -0.8928393030645658], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMang2" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0, 1.0])
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([-4, 0, 6]))), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0, 0, 0], atol=1e-3)
    @test isapprox(flex_actor2.x, [0, 0, 0], atol=1e-3)
    @test isapprox(flex_actor3.x, [-5.6179147130732225, 0, 5.617914767964074], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end


@testset "TestFlexADMMAWithMangoPriosThird" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0, 1.0])
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([-4, 0, 6], [1,1,5]))), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.00018920502370025307, -6.385117748282918e-5, 0.0001192856645796826], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.00018947342781542052, -6.398798323709664e-5, 0.00011955174808086514], atol=1e-3)
    @test isapprox(flex_actor3.x, [-6.024383392342817, -8.105452791414886e-7, 6.02438348197089], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMangoPriosFirst" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0, 1.0])
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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([-4, 0, 6], [5,1,1]))), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.00018920502370025307, -6.385117748282918e-5, 0.0001192856645796826], atol=1e-3)
    @test isapprox(flex_actor2.x, [0.00018947342781542052, -6.398798323709664e-5, 0.00011955174808086514], atol=1e-3)
    @test isapprox(flex_actor3.x, [-3.9830282351073403, -7.203077063324391e-7, 3.98302823714599], atol=1e-3)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end