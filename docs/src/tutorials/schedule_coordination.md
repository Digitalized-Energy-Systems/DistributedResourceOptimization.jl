# Tutorial: Schedule Coordination with COHDA

This tutorial shows how to use COHDA to coordinate a group of participants that each
select a power schedule from a menu of options, with the goal of matching a target
aggregate profile.

## Problem Statement

Four distributed energy units (e.g., controllable loads) participate in a demand-response
event. The grid operator asks for an aggregate power profile of `[3.0, 2.0, 1.0]` kW over
three time steps.

Each unit can only operate in one of several predefined modes (schedules). The task is
to find a combination — one schedule per unit — whose sum is as close as possible to the
target.

## Step 1 — Define the Participants

Each participant is created with [`create_cohda_participant`](@ref). Arguments:

- `id` — unique integer identifier
- `schedules` — vector of candidate schedules (each a `Vector{Float64}` of the same length
  as the target)

```@example cohda-tutorial
using DistributedResourceOptimization

# Unit A: can be OFF, run at half power, or run at full power
schedules_A = [
    [0.0, 0.0, 0.0],   # OFF
    [1.0, 0.5, 0.0],   # half power
    [2.0, 1.0, 0.5],   # full power
]

# Unit B: similar options but different profile shapes
schedules_B = [
    [0.0, 0.0, 0.0],
    [0.5, 1.0, 0.5],
    [1.0, 1.0, 0.5],
]

unit_A1 = create_cohda_participant(1, schedules_A)
unit_A2 = create_cohda_participant(2, schedules_A)
unit_B1 = create_cohda_participant(3, schedules_B)
unit_B2 = create_cohda_participant(4, schedules_B)
```

## Step 2 — Create the Start Message

The start message carries the target profile that all participants try to match
collectively:

```@example cohda-tutorial
target    = [3.0, 2.0, 1.0]
start_msg = create_cohda_start_message(target)
```

## Step 3 — Run the Distributed Optimization

```@example cohda-tutorial
wait(start_distributed_optimization(
    [unit_A1, unit_A2, unit_B1, unit_B2],
    start_msg,
))
```

`start_distributed_optimization` uses a `SimpleCarrier` internally. The call returns a
task; `wait` blocks until the algorithm converges.

## Step 4 — Inspect the Result

After convergence, the selected schedule for each participant is stored in its
`WorkingMemory`. You can access it via the algorithm's internal state:

```@example cohda-tutorial
# The memory field holds the best found system configuration
wm = unit_A1.memory

# The solution candidate holds the selected schedules as a Matrix (rows = participants)
println("Best performance: ", wm.solution_candidate.perf)

# Extract the aggregate (sum over participants) of the chosen schedules
aggregate = vec(sum(wm.solution_candidate.schedules, dims=1))
println("Aggregate schedule: ", aggregate)
println("Target:             ", target)
println("L1 deviation:       ", sum(abs.(aggregate .- target)))
```

## Complete Script

```@example cohda-tutorial-full
using DistributedResourceOptimization

# Schedule menus
schedules_A = [[0.0, 0.0, 0.0], [1.0, 0.5, 0.0], [2.0, 1.0, 0.5]]
schedules_B = [[0.0, 0.0, 0.0], [0.5, 1.0, 0.5], [1.0, 1.0, 0.5]]

# Participants
participants = [
    create_cohda_participant(1, schedules_A),
    create_cohda_participant(2, schedules_A),
    create_cohda_participant(3, schedules_B),
    create_cohda_participant(4, schedules_B),
]

# Target and start
target    = [3.0, 2.0, 1.0]
start_msg = create_cohda_start_message(target)

# Solve
wait(start_distributed_optimization(participants, start_msg))

# Report
wm        = participants[1].memory
aggregate = vec(sum(wm.solution_candidate.schedules, dims=1))
println("Aggregate schedule: ", round.(aggregate; digits=3))
println("Target:             ", target)
println("L1 deviation:       ", round(sum(abs.(aggregate .- target)); digits=4))
```

## Using SimpleCarrier Directly

If you need more control — for example, to inspect intermediate messages or integrate with
a larger simulation — use `SimpleCarrier` explicitly:

```@example cohda-tutorial-simple
using DistributedResourceOptimization

schedules_A = [[0.0, 0.0, 0.0], [1.0, 0.5, 0.0], [2.0, 1.0, 0.5]]

container = ActorContainer()
carrier1  = SimpleCarrier(container, create_cohda_participant(1, schedules_A))
carrier2  = SimpleCarrier(container, create_cohda_participant(2, schedules_A))

start_msg = create_cohda_start_message([2.0, 1.0, 0.5])

# Send start message from carrier1 to carrier2; returns a task
task = send_to_other(carrier1, start_msg, cid(carrier2))
wait(task)
```

## Extending with Custom Performance

By default COHDA uses a weighted L1 distance. Supply a custom performance function to
[`create_cohda_participant`](@ref) to optimise a different objective. The function receives
a `Matrix{Float64}` (rows = participants, columns = time steps) and a `TargetParams` struct:

```@example cohda-tutorial-custom
using DistributedResourceOptimization

schedules_A = [[0.0, 0.0, 0.0], [1.0, 0.5, 0.0], [2.0, 1.0, 0.5]]

# Minimise L2 (Euclidean) distance instead of the default weighted L1
my_perf = (cluster_schedule, target_params) ->
    -sqrt(sum((target_params.schedule .- vec(sum(cluster_schedule, dims=1))) .^ 2))

unit = create_cohda_participant(1, (_) -> schedules_A, my_perf)
```

!!! note "Heuristic Quality"
    COHDA is a heuristic and may not find the global optimum, especially with many
    participants or a large schedule menu. In practice it converges quickly to near-optimal
    solutions on problems of realistic size (tens to hundreds of participants).

## Next Steps

- See [COHDA algorithm details](../algorithms/cohda.md) for the mathematical background
- Try the [Energy Dispatch Tutorial](energy_dispatch.md) for the continuous ADMM variant
- See [How To: Implement a Custom Algorithm](../howtos/custom_algorithm.md) to add your own
  heuristic
