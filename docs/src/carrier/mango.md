To use the distributed algorithms, the role [`DistributedOptimizationRole`](@ref) can be used to integrate an algorithm. 

Some distributed algorithms require a coordinator, in this case another role can be used additionally [`CoordinatorRole`](@ref).

```julia
using Mango
using DistributedResourceOptimization

container = create_tcp_container("127.0.0.1", 5555)

agent_one = add_agent_composed_of(container, DistributedOptimizationRole(
    create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])))
agent_two = add_agent_composed_of(container, DistributedOptimizationRole(
    create_cohda_participant(2, [[0.0, 1, 2], [1, 2, 3]])))

initial_message = create_cohda_start_message([1.2, 2, 3])

auto_assign!(complete_topology(2), container)

activate(container) do
    send_message(agent_one, initial_message, address(agent_two))
end
```