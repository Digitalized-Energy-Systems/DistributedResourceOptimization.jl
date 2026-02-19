# COHDA

**COHDA** (Combinatorial Optimization Heuristic for Distributed Agents) is a fully distributed
heuristic for the Multiple-Choice Combinatorial Optimization Problem (MC-COP). It requires no
central coordinator — participants exchange *solution candidates* with their neighbors and
converge through local search.

## Problem Formulation

Each of the ``N`` participants independently selects exactly one schedule from a personal menu of
``M`` choices. The goal is to minimize the L1 distance of the combined schedule sum to a target
vector ``T``:

```math
\begin{equation}
  \begin{split}
      &\underset{x_{i,j}}{\text{max}}\;\left(-\bigl\lVert T - \sum_{i=1}^{N}\sum_{j=1}^{M} U_{i,j}\cdot x_{i,j}\bigr\rVert_1\right)\\
      &\text{s.t.}\quad \sum_{j=1}^{M} x_{i,j} = 1 \quad \forall\, i\\
      &\phantom{\text{s.t.}\quad} x_{i,j}\in\{0,1\},\quad i=1,\dots,N,\; j=1,\dots,M
  \end{split}
\end{equation}
```

where ``U_{i,j} \in \mathbb{R}^m`` is the ``j``-th schedule of participant ``i``.

## How It Works

COHDA is a gossip-style algorithm:

1. A *start message* carrying the target ``T`` is sent to one participant.
2. Upon receiving a message, each participant updates its *working memory* — a view of the
   current best known system configuration — and then applies local search to improve its own
   schedule selection.
3. If the working memory changed, the participant broadcasts an updated *solution candidate*
   to all its neighbors.
4. The algorithm terminates when no participant can improve the objective any further (the
   system configuration stabilises across all participants).

## Usage

Create participants with [`create_cohda_participant`](@ref):

```@example cohda-usage
using DistributedResourceOptimization

# Participant 1: two schedule choices, each 3-dimensional
actor_one = create_cohda_participant(1, [[0.0, 1.0, 2.0],
                                         [1.0, 2.0, 3.0]])

# Participant 2: two schedule choices
actor_two = create_cohda_participant(2, [[0.0, 1.0, 2.0],
                                         [1.0, 2.0, 3.0]])
```

The first argument is a unique participant ID (integer); the second is a vector of schedules,
each of which must have the same length as the target vector.

Start the optimization with a target vector using [`create_cohda_start_message`](@ref):

```@example cohda-usage
start_msg = create_cohda_start_message([1.2, 2.0, 3.0])

wait(start_distributed_optimization([actor_one, actor_two], start_msg))
```

## Complete Example

```@example cohda-complete
using DistributedResourceOptimization

# Four participants, each with three schedule options of length 4
schedules_A = [[1.0, 0.0, 0.0, 0.0],
               [0.0, 1.0, 0.0, 0.0],
               [0.0, 0.0, 1.0, 0.0]]

schedules_B = [[2.0, 0.0, 0.0, 0.0],
               [0.0, 2.0, 0.0, 0.0],
               [0.0, 0.0, 0.0, 2.0]]

actors = [
    create_cohda_participant(1, schedules_A),
    create_cohda_participant(2, schedules_B),
    create_cohda_participant(3, schedules_A),
    create_cohda_participant(4, schedules_B),
]

# Target: the combined schedule should be close to [3, 3, 1, 2]
start_msg = create_cohda_start_message([3.0, 3.0, 1.0, 2.0])

wait(start_distributed_optimization(actors, start_msg))
```

## Working Memory and Solution Candidates

Internally COHDA uses:

- **`WorkingMemory`** — each participant's current view of the world: the target parameters, the
  best known system configuration (`SystemConfig`), and the best known solution candidate
  (`SolutionCandidate`).
- **`SystemConfig`** — a mapping from participant IDs to their currently selected schedule.
- **`SolutionCandidate`** — a proposed full system configuration together with its performance
  value (negative L1 distance to target).

These types are exported and can be inspected after the algorithm runs.

## Custom Performance Functions

By default COHDA uses a weighted L1 distance metric. You can provide a custom performance
function when creating a participant. The function receives a `Matrix{Float64}` (rows =
participants, columns = time steps) and a `TargetParams` struct, and must return a `Float64`:

```@example cohda-custom
using DistributedResourceOptimization

schedules_A = [[1.0, 0.0, 0.0, 0.0],
               [0.0, 1.0, 0.0, 0.0],
               [0.0, 0.0, 1.0, 0.0]]

# Custom performance using L2 distance instead of the default weighted L1
my_perf = (cluster_schedule, target_params) ->
    -sqrt(sum((target_params.schedule .- vec(sum(cluster_schedule, dims=1))) .^ 2))

actor = create_cohda_participant(1, (_) -> schedules_A, my_perf)
```

!!! note "Convergence"
    COHDA is a heuristic and does not guarantee a globally optimal solution.
    Quality typically improves with more participants and more schedule choices.
    Convergence is detected when the system configuration stabilises across all participants.

## See Also

- [`create_cohda_participant`](@ref), [`create_cohda_start_message`](@ref)
- [`WorkingMemory`](@ref), [`SolutionCandidate`](@ref), [`SystemConfig`](@ref)
- [Tutorial: Schedule Coordination with COHDA](../tutorials/schedule_coordination.md)
