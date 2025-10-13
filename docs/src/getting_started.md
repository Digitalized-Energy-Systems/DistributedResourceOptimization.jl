### Using the sharing ADMM with flex actors (e.g. for resource optimization) with Mango.jl

```julia
using Mango
using DistributedResourceOptimization

@role struct HandleOptimizationResultRole
    got_it::Bool = false
end

function Mango.handle_message(role::HandleOptimizationResultRole, message::OptimizationFinishedMessage, meta::Any)
    role.got_it = true
end

container = create_tcp_container("127.0.0.1", 5555)

# create participant models
flex_actor = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])
flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1])
flex_actor3 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1])

# create coordinator with objective
coordinator = create_sharing_target_distance_admm_coordinator()

# create roles to integrate admm in Mango.jl
dor = DistributedOptimizationRole(flex_actor, tid=:custom)
dor2 = DistributedOptimizationRole(flex_actor2, tid=:custom)
dor3 = DistributedOptimizationRole(flex_actor3, tid=:custom)
coord_role = CoordinatorRole(coordinator, tid=:custom, include_self=true)

# role to handle a result
handle = HandleOptimizationResultRole()
handle2 = HandleOptimizationResultRole()
handle3 = HandleOptimizationResultRole()

# create agents
add_agent_composed_of(container, dor, handle)
c = add_agent_composed_of(container, dor2, handle2)
ca = add_agent_composed_of(container, coord_role, dor3, handle3)

# create a topology of the agents
auto_assign!(complete_topology(3, tid=:custom), container)

# run the simulation with start message and wait for result
activate(container) do
    wait(send_message(c, StartCoordinatedDistributedOptimization(create_admm_start(create_admm_sharing_data([0.2, 1, -2]))), address(ca)))
    wait(coord_role.task)
end
```

### Using COHDA with Mango.jl

```julia
using Mango
using DistributedResourceOptimization

container = create_tcp_container("127.0.0.1", 5555)

# create agents with local model wrapped in the general distributed optimization role
agent_one = add_agent_composed_of(container, DistributedOptimizationRole(
    create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])))
agent_two = add_agent_composed_of(container, DistributedOptimizationRole(
    create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]])))

# create start message
initial_message = create_cohda_start_message([1.2, 2, 3])

# create topology
auto_assign!(complete_topology(2), container)

# run simulation
activate(container) do
    send_message(agent_one, initial_message, address(agent_two))
end
```
