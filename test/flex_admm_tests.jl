using Mango
using DistributedOptimization
using Test

@testset "TestFlexADMMWithMangoCarrier" begin
    container = create_tcp_container("127.0.0.1", 5555)

    m = 2
    l = zeros(m)
    u = [6.0, 4.0]
    C = [ 1.0 1.0;
         -2/3 1.0;
         -2/3 1.0]
    d = [10.0; 0.0; 0.0]

    flex_actor = ADMMFlexActor(l, u, C, d)
    flex_actor2 = ADMMFlexActor(l, [3.0,2.0], C, [20.0;0.0;0.0])
    dor = DistributedOptimizationRole(flex_actor)
    dor2 = DistributedOptimizationRole(flex_actor2)

    coordinator = ADMMFlexCoordinator()
    coord_role = CoordinatorRole(coordinator)
    
    add_agent_composed_of(container, dor)
    add_agent_composed_of(container, dor2)
    ca = add_agent_composed_of(container, coord_role)
    
    auto_assign!(complete_topology(3), container)

    activate(container) do
        send_message(container, StartCoordinatedDistributedOptimization([1.0, 2.0]), address(ca))
    end

    @test flex_actor.x == [0.8076923071828561, 0.5384616848406112]
    @test flex_actor2.x == [0.8076923071828561, 0.5384616848406112]
end



@testset "TestFlexADMMWithMangoCarrierConvCreate" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor2 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    coordinator = ADMMFlexCoordinator()

    dor = DistributedOptimizationRole(flex_actor, tid=:custom)
    dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
    coord_role = CoordinatorRole(coordinator, tid=:custom)
    
    add_agent_composed_of(container, dor)
    add_agent_composed_of(container, dor2)
    ca = add_agent_composed_of(container, coord_role)
    
    auto_assign!(complete_topology(3, tid=:custom), container)

    activate(container) do
        send_message(container, StartCoordinatedDistributedOptimization([1.0, 2.0]), address(ca))
    end

    @test result(flex_actor) == flex_actor.x == [0.807682990194497, 0.5384948521038107]
    @test result(flex_actor2) == flex_actor2.x == [0.807682990194497, 0.5384948521038107]
end

@role struct HandleOptimizationResultRole
    got_it::Bool = false
end

function Mango.handle_message(role::HandleOptimizationResultRole, message::OptimizationFinishedMessage, meta::Any)
    role.got_it = true
end

@testset "TestFlexADMMAWithMangoCarrierConvCreateCoordAsActor" begin
    container = create_tcp_container("127.0.0.1", 5555)

    flex_actor = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor2 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
    flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.6, 0.4])
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
        wait(send_message(c, StartCoordinatedDistributedOptimization([1.0, 2.0]), address(ca)))
        wait(coord_role.task)
    end

    @test result(flex_actor) == flex_actor.x == [0.5384464199808827, 0.3590100413570222]
    @test result(flex_actor2) == flex_actor2.x == [0.5384464199808827, 0.3590100413570222]
    @test result(flex_actor3) == flex_actor3.x == [0.5384464199808827, 0.3590100413570222]
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end