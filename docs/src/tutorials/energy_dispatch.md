# Tutorial: Energy Dispatch with ADMM

This tutorial walks through using ADMM to coordinate flexible energy resources — heat
pumps, batteries, and PV inverters — so that their combined power output matches a
target profile.

## Problem Statement

Suppose an aggregator controls three flexible resources. Each resource converts an input
power into outputs across three sectors (e.g., thermal, electrical, reactive power).
The aggregator wants the combined output to be as close as possible to:

```
target = [-4.0, 0.0, 6.0]  kW
```

with the first sector weighted five times more heavily than the others (e.g., it is a
critical load).

## Step 1 — Define the Resources

Each resource is modelled as an ADMM flex actor. The constructor
[`create_admm_flex_actor_one_to_many`](@ref) takes:

- `in_capacity` — maximum input power in kW
- `η` — efficiency vector mapping input to outputs (negative means the resource *consumes*
  that output type)
- `P` (optional) — priority penalty vector that biases the local solution

```@example admm-tutorial
using DistributedResourceOptimization

# Resource 1: 10 kW heat pump — produces thermal (η₁=0.1) and electrical (η₂=0.5),
#             consumes reactive power (η₃=−1.0)
resource1 = create_admm_flex_actor_one_to_many(10.0, [0.1, 0.5, -1.0])

# Resource 2: 15 kW battery — same conversion ratios, higher capacity
resource2 = create_admm_flex_actor_one_to_many(15.0, [0.1, 0.5, -1.0])

# Resource 3: 10 kW PV inverter — consumes thermal, neutral electrical, produces reactive
resource3 = create_admm_flex_actor_one_to_many(10.0, [-1.0, 0.0, 1.0])
```

## Step 2 — Create the Coordinator

The coordinator solves the global z-update each ADMM iteration. We use the sharing
variant, which minimises the weighted distance of the aggregate output to the target:

```@example admm-tutorial
coordinator = create_sharing_target_distance_admm_coordinator()
```

## Step 3 — Set Up the Problem Data

[`create_admm_sharing_data`](@ref) bundles the target vector and priority weights:

```@example admm-tutorial
# target = [-4, 0, 6], priorities = [5, 1, 1]
problem_data = create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1])
start_msg    = create_admm_start(problem_data)
```

The priority weight `5` for the first sector means deviations there are penalised five
times more than deviations in the other two sectors.

## Step 4 — Run the Optimization

```@example admm-tutorial
start_coordinated_optimization(
    [resource1, resource2, resource3],
    coordinator,
    start_msg,
)
```

This call blocks until the ADMM algorithm converges (or hits `max_iters`).

## Step 5 — Read the Results

After convergence, retrieve each resource's optimal output vector with
[`result`](@ref):

```@example admm-tutorial
x1 = result(resource1)
x2 = result(resource2)
x3 = result(resource3)

println("Resource 1 output: ", round.(x1; digits=3))
println("Resource 2 output: ", round.(x2; digits=3))
println("Resource 3 output: ", round.(x3; digits=3))
println("Aggregate:         ", round.(x1 .+ x2 .+ x3; digits=3))
println("Target:            ", [-4.0, 0.0, 6.0])
```

## Complete Script

```@example admm-tutorial-full
using DistributedResourceOptimization

# Resources
resource1 = create_admm_flex_actor_one_to_many(10.0, [0.1,  0.5, -1.0])
resource2 = create_admm_flex_actor_one_to_many(15.0, [0.1,  0.5, -1.0])
resource3 = create_admm_flex_actor_one_to_many(10.0, [-1.0, 0.0,  1.0])

# Coordinator and problem
coordinator  = create_sharing_target_distance_admm_coordinator()
problem_data = create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1])
start_msg    = create_admm_start(problem_data)

# Solve
start_coordinated_optimization([resource1, resource2, resource3], coordinator, start_msg)

# Results
x1, x2, x3 = result(resource1), result(resource2), result(resource3)
println("Resource 1: ", round.(x1; digits=3))
println("Resource 2: ", round.(x2; digits=3))
println("Resource 3: ", round.(x3; digits=3))
println("Aggregate:  ", round.(x1 .+ x2 .+ x3; digits=3))
```

## Tuning Convergence

If the result is not accurate enough, or convergence is slow, build an
[`ADMMGenericCoordinator`](@ref) directly to override any parameter:

```@example admm-tune
using DistributedResourceOptimization

resource1 = create_admm_flex_actor_one_to_many(10.0, [0.1,  0.5, -1.0])
resource2 = create_admm_flex_actor_one_to_many(15.0, [0.1,  0.5, -1.0])
resource3 = create_admm_flex_actor_one_to_many(10.0, [-1.0, 0.0,  1.0])

coordinator = ADMMGenericCoordinator(
    global_actor = ADMMSharingGlobalActor(ADMMTargetDistanceObjective()),
    ρ            = 5.0,    # larger ρ enforces constraints more aggressively
    max_iters    = 500,    # allow more iterations
    abs_tol      = 1e-5,   # tighter tolerance
    rel_tol      = 1e-4,
)

start_msg = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))
start_coordinated_optimization([resource1, resource2, resource3], coordinator, start_msg)

x1, x2, x3 = result(resource1), result(resource2), result(resource3)
println("Aggregate:  ", round.(x1 .+ x2 .+ x3; digits=3))
```

!!! tip "Priority Weights"
    Setting large priority weights for a sector (e.g., `[100, 1, 1]`) forces the optimizer
    to match that sector's target as closely as possible, potentially at the expense of other
    sectors. Use this to encode hard priorities in soft constraints.

## Next Steps

- Try adding a fourth resource and observe how the aggregate adapts
- Experiment with different efficiency vectors `η` to model other resource types
- See [ADMM algorithm details](../algorithms/admm.md) for the mathematical background
- See [How To: Implement a Custom Algorithm](../howtos/custom_algorithm.md) to write your
  own local model
