# Averaging Consensus

The Averaging Consensus algorithm distributes a parameter vector ``\lambda`` across ``N`` agents
via a gossip-style protocol. Each agent maintains its own copy of ``\lambda`` and iteratively
averages it with values received from neighbors. An optional gradient term allows each agent
to steer the consensus towards locally desirable values.

## Algorithm

Let ``\lambda_i^k`` be the value held by agent ``i`` at iteration ``k``. The update rule is:

```math
\lambda_i^{k+1} = \lambda_i^k + \alpha \left(\bar{\lambda}^k - \lambda_i^k\right) + \nabla_i^k
```

where

- ``\bar{\lambda}^k`` is the average of all received values at iteration ``k``
- ``\alpha \in (0,1]`` is the step size (mixing parameter)
- ``\nabla_i^k = \text{gradient\_term}(\text{actor}_i, \lambda_i^k, \text{data})`` is the
  local gradient correction (zero by default)

The algorithm runs for a fixed number of iterations (`max_iter`) after which each agent calls
a user-supplied `finish_callback`.

## Usage

Create a participant with [`create_averaging_consensus_participant`](@ref):

```@example consensus-usage
using DistributedResourceOptimization

actor = create_averaging_consensus_participant(
    # finish_callback: called with (algorithm, carrier) when max_iter is reached
    (alg, _) -> println("Converged to λ = ", alg.λ),
    NoConsensusActor();  # no local gradient correction
    initial_λ = 10.0,   # starting value for all components
    α         = 0.3,    # mixing step size
    max_iter  = 50,     # number of gossip rounds
)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `finish_callback` | `Function` | — | Called with `(algorithm, carrier)` when `max_iter` is reached |
| `consensus_actor` | `ConsensusActor` | — | Provides the local gradient term; use `NoConsensusActor()` for pure averaging |
| `initial_λ` | `Real` | `10` | Initial value broadcast to all components of `λ` |
| `α` | `Real` | `0.3` | Mixing step size |
| `max_iter` | `Int` | `50` | Number of gossip rounds before finishing |

## Local Gradient Corrections

To steer the consensus, implement a custom [`ConsensusActor`](@ref) and override
[`gradient_term`](@ref):

```@example consensus-gradient
using DistributedResourceOptimization

# Actor that pushes λ towards a local target
struct MyActor <: ConsensusActor
    target::Vector{Float64}
    β::Float64   # gradient step size
end

function gradient_term(actor::MyActor, λ::Vector{<:Real}, ::Any)
    return actor.β .* (actor.target .- λ)
end
```

The `data` argument carries whatever was embedded in the initial
[`AveragingConsensusMessage`](@ref) — useful for passing problem data alongside the consensus.

## Complete Example — Pure Averaging

```@example consensus-pure
using DistributedResourceOptimization

# Three agents starting at λ = 5, 10, 15 will converge to their average (≈ 10)
actor1 = create_averaging_consensus_participant((_, _) -> nothing, NoConsensusActor();
             initial_λ=5.0, α=0.5, max_iter=30)
actor2 = create_averaging_consensus_participant((_, _) -> nothing, NoConsensusActor();
             initial_λ=10.0, α=0.5, max_iter=30)
actor3 = create_averaging_consensus_participant((_, _) -> nothing, NoConsensusActor();
             initial_λ=15.0, α=0.5, max_iter=30)

# The start message sets the λ dimension (1-D here); initial=true triggers setup
start_msg = AveragingConsensusMessage([0.0], 0, nothing, true)

wait(start_distributed_optimization([actor1, actor2, actor3], start_msg))

# Gossip rounds run asynchronously — wait until actor1 has finished all iterations
wait(Threads.@spawn while actor1.k < 30; sleep(0.01); end)

println("actor1 λ ≈ ", round.(actor1.λ; digits=3))  # converges to ≈ [10.0]
println("actor2 λ ≈ ", round.(actor2.λ; digits=3))
println("actor3 λ ≈ ", round.(actor3.λ; digits=3))
```

## Complete Example — Economic Dispatch

The built-in [`LinearCostEconomicDispatchConsensusActor`](@ref) implements consensus-based
economic dispatch, where each agent has a linear cost and power limits:

```julia
using DistributedResourceOptimization

# TODO: example to be documented once LinearCostEconomicDispatchConsensusActor API is stable
```

!!! note "Termination"
    The algorithm terminates after exactly `max_iter` gossip rounds — there is no residual-based
    stopping criterion. Choose `max_iter` large enough for your network topology; in a fully
    connected graph convergence is typically fast (10–30 rounds).

## See Also

- [`create_averaging_consensus_participant`](@ref), [`AveragingConsensusAlgorithm`](@ref)
- [`ConsensusActor`](@ref), [`NoConsensusActor`](@ref), [`gradient_term`](@ref)
- [`LinearCostEconomicDispatchConsensusActor`](@ref)
