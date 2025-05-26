using Mango
using DistributedOptimization
using Test


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
    coordinator = ADMMFlexCoordinator(T=[1.0, 2.0])

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
        wait(send_message(c, StartCoordinatedDistributedOptimization(), address(ca)))
        wait(coord_role.task)
    end

    @test result(flex_actor) == flex_actor.x == [0.5384464199808827, 0.3590100413570222]
    @test result(flex_actor2) == flex_actor2.x == [0.5384464199808827, 0.3590100413570222]
    @test result(flex_actor3) == flex_actor3.x == [0.5384464199808827, 0.3590100413570222]
    @test handle.got_it
    @test handle2.got_it
    @test handle3.got_it
end