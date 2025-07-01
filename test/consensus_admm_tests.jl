using Mango
using DistributedOptimization
using Test

@role struct HandleOptimizationResultRole
    got_it::Bool = false
end

function Mango.handle_message(role::HandleOptimizationResultRole, message::OptimizationFinishedMessage, meta::Any)
    role.got_it = true
end

@testset "TestFlexADMMWithMangoCarrier" begin
    container = create_tcp_container("127.0.0.1", 5555)

    m = 2
    l = zeros(m)
    u = [6.0, 4.0]
    C = [ 1.0 1.0;
         -2/3 1.0;
         -2/3 1.0]
    d = [10.0; 0.0; 0.0]
    S = [0, 0, 0.0]

    flex_actor = ADMMFlexActor(l, u, C, d, S)
    flex_actor2 = ADMMFlexActor(l, [3.0,2.0], C, [20.0;0.0;0.0], [2.0,2.0,2.0])
    dor = DistributedOptimizationRole(flex_actor)
    dor2 = DistributedOptimizationRole(flex_actor2)

    coordinator = create_consensus_target_reach_admm_coordinator()
    coord_role = CoordinatorRole(coordinator)
    
    add_agent_composed_of(container, dor)
    add_agent_composed_of(container, dor2)
    ca = add_agent_composed_of(container, coord_role)
    
    auto_assign!(complete_topology(3), container)

    activate(container) do
        send_message(container, StartCoordinatedDistributedOptimization(create_admm_start_with_target([1.0, 1.0])), address(ca))
    end

    @test isapprox(flex_actor.x, [1.1538631043061336, 0.7692460141088975], atol=1e-3)
    @test isapprox(flex_actor2.x, [-0.0002818560107043097, -0.00018497087323324864], atol=1e-3)
end

@testset "TestFlexADMMWithMangoCarrierConvCreate" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor2 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    coordinator = create_consensus_target_reach_admm_coordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom)
    
    add_agent_composed_of(container, dor)
    add_agent_composed_of(container, dor2)
    ca = add_agent_composed_of(container, coord_role)
    
    auto_assign!(complete_topology(3, tid=:custom), container)

    activate(container) do
        send_message(container, StartCoordinatedDistributedOptimization(create_admm_start_with_target([1.0, 2.0])), address(ca))
    end

    @test isapprox(flex_actor.x, [0.807, 0.538], rtol=1e-2)
    @test isapprox(flex_actor2.x, [0.807, 0.538], rtol=1e-2)
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActor" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor2 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    coordinator = create_consensus_target_reach_admm_coordinator()

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
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start_with_target([1.0, 2.0])), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [0.538, 0.359], rtol=1e-2)
    @test isapprox(flex_actor2.x, [0.538, 0.359], rtol=1e-2)
    @test isapprox(flex_actor3.x, [0.538, 0.359], rtol=1e-2)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActorComplex" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = ADMMFlexActor([0.0, 0.0, 0.0],
    [6.428571428571429, 0.0, 4.5], 
    [1.0 1.0 1.0; 0.15555555555555556 0.0 -0.2222222222222222; -0.15555555555555556 0.0 0.2222222222222222; 0.0 0.0 0.0; 0.0 0.0 0.0], 
    [10.928571428571429, 0.0, 0.0, 0.0, 0.0], [0.0,0,0])

    flex_actor2 = ADMMFlexActor([0.0, 0.0, 0.0], 
    [0.04000000000000001, 0.06, 0.1], 
    [1.0 1.0 1.0; 24.999999999999996 0.0 -10.0; -24.999999999999996 0.0 10.0; 0.0 16.666666666666668 -10.0; 0.0 -16.666666666666668 10.0], 
    [0.2, 0.0, 0.0, 0.0, 0.0], [0.0,0,0])
    
    flex_actor3 = ADMMFlexActor([0.0, 0.0, 0.0], 
    [0.3, 0.0, 0.3333333333333333], 
    [1.0 1.0 1.0; 3.3333333333333335 0.0 -3.0; -3.3333333333333335 0.0 3.0; 0.0 0.0 0.0; 0.0 0.0 0.0], 
    [0.6333333333333333, 0.0, 0.0, 0.0, 0.0], [0.0,0,0])
    
    flex_actor4 = ADMMFlexActor([0.0, 0.0, 0.0], 
    [1.5, 0.0, 1.6666666666666665], 
    [1.0 1.0 1.0; 0.6666666666666666 0.0 -0.6000000000000001; -0.6666666666666666 0.0 0.6000000000000001; 0.0 0.0 0.0; 0.0 0.0 0.0], 
    [3.1666666666666665, 0.0, 0.0, 0.0, 0.0], [0.0,0,0])

    coordinator = create_consensus_target_reach_admm_coordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    dor3 = DistributedOptimizationRole(flex_actor3, tid=:custom)
    dor4 = DistributedOptimizationRole(flex_actor4, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom, include_self=true)

    handle = HandleOptimizationResultRole()
    handle2 = HandleOptimizationResultRole()
    handle3 = HandleOptimizationResultRole()
    handle4 = HandleOptimizationResultRole()

    add_agent_composed_of(container, dor, handle)
    c = add_agent_composed_of(container, dor2, handle2)
    ca = add_agent_composed_of(container, coord_role, dor3, handle3)
    add_agent_composed_of(container, dor4, handle3)
    
    auto_assign!(complete_topology(4, tid=:custom), container)

    activate(container) do
        wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start_with_target([22.559000761215636, -0.0, 22.559000761215636])), address(ca)))
        wait(coord_role.task)
    end

    @test isapprox(flex_actor.x, [6.42853816370231, -1.785956854356477e-6, 4.499978435684416], rtol=1e-2)
    @test isapprox(flex_actor2.x, [0.040013413013280125, 0.0600214071909219, 0.10000099993773309], rtol=1e-2)
    @test isapprox(flex_actor3.x, [0.3000377811917589, -2.683958412610146e-7, 0.33336868924468077], rtol=1e-2)
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActorNegativeEff" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor2 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
    coordinator = ADMMFlexCoordinator()

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