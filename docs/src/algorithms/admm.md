# ADMM

The Alternating Direction Method of Multipliers (ADMM) is a convex optimization algorithm
that decomposes a large problem into smaller subproblems solved locally, coordinated by a
central update. DRO implements two ADMM variants: **Sharing** and **Consensus**.

## Problem Forms

### Sharing

The sharing form distributes a resource across ``N`` agents whose individual contributions
must sum to a global variable ``z``:

```math
\begin{equation}
\begin{split}
\min_{\{x_i\},\,z}\;\; \sum_{i=1}^N f_i(x_i) \;+\; g(z) \\
\quad\text{s.t.}\quad \sum_{i=1}^N x_i = z
\end{split}
\end{equation}
```

where ``f_i`` is the local cost of agent ``i``, ``x_i \in \mathbb{R}^m`` its decision variable,
and ``g`` a global penalty on the aggregate ``z``.

The ADMM iterations with dual variable ``u`` and penalty ``\rho`` are:

```math
\begin{align}
x_i^{k+1}
  &= \arg\min_{x_i}\;
     f_i(x_i) + \tfrac{\rho}{2}\,\big\lVert x_i - (z^k - u^k) \big\rVert_2^2,
     \quad i=1,\dots,N
     \\[4pt]
\bar{x}^{\,k+1}
  &= \tfrac{1}{N}\sum_{i=1}^N x_i^{k+1}
     \\[4pt]
z^{k+1}
  &= \arg\min_{z}\;
     g(N\cdot z) + \tfrac{N\rho}{2}\,\big\lVert z - \bar{x}^{\,k+1} - u^k \big\rVert_2^2
     \\[4pt]
u^{k+1}
  &= u^k + \bar{x}^{\,k+1} - z^{k+1}
\end{align}
```

To create a coordinator for this form use [`create_sharing_target_distance_admm_coordinator`](@ref),
and start the negotiation with [`create_admm_start`](@ref).

### Consensus

The consensus form drives all agents to agree on a single global value ``z``:

```math
\begin{equation}
\begin{split}
\min_{\{x_i\},\,z}\;\; \sum_{i=1}^N f_i(x_i) \\
\quad\text{s.t.}\quad x_i = z,\;\; i=1,\dots,N
\end{split}
\end{equation}
```

The update iterations are:

```math
\begin{align}
x_i^{k+1}
  &= \arg\min_{x_i}\;
     f_i(x_i) + \frac{\rho}{2}\big\| x_i - \big(z^k - u_i^k \big) \big\|_2^2
     \\[4pt]
z^{k+1}
  &= \arg\min_{z}\;
     g(z) + \frac{N \rho}{2}\left\|
     z - \Big( \bar{x}^{k+1} + \bar{u}^k \Big)
     \right\|_2^2 \\[4pt]
u_i^{k+1}
  &= u_i^k + x_i^{k+1} - z^{k+1}
\end{align}
```

To create a coordinator for the consensus form use [`create_consensus_target_reach_admm_coordinator`](@ref),
and to construct the start message use [`create_admm_start_consensus`](@ref).

## Local Model: Flexibility Actor

Each participant is modelled as a *flexibility actor* — a local resource with bounded and coupled
decision variables:

| Constraint | Description |
|-----------|-------------|
| ``l_i \leq x_i \leq u_i`` | Box constraints (lower/upper bounds per sector) |
| ``C_i x_i \leq d_i`` | Coupling constraints (e.g., input-output coupling) |
| ``S_i^\top x_i`` | Linear priority penalty added to the local objective |

At each ADMM iteration the actor solves a small QP (via OSQP) to compute ``x_i^{k+1}``.

### One-to-Many Resource

A common model is a resource that converts a single input into ``m`` outputs with given
efficiencies ``\eta \in \mathbb{R}^m``. Use [`create_admm_flex_actor_one_to_many`](@ref):

```julia
# 10 kW input capacity, three outputs with efficiencies [0.1, 0.5, -1.0]
# Negative efficiency means the resource *consumes* that output type.
actor = create_admm_flex_actor_one_to_many(10.0, [0.1, 0.5, -1.0])
```

An optional priorities vector ``P`` biases the solution towards specific sectors:

```julia
# Prefer sector 1 with priority 5
actor = create_admm_flex_actor_one_to_many(10.0, [0.1, 0.5, -1.0], [5.0, 0.0, 0.0])
```

After the optimization finishes, retrieve the result with:

```julia
x_opt = result(actor)   # Vector{Float64} of length m
```

## Coordinator Parameters

The generic ADMM coordinator ([`ADMMGenericCoordinator`](@ref)) exposes several tuning parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ρ` | `1.0` | Penalty parameter — larger values enforce constraints faster but may slow convergence |
| `max_iters` | `1000` | Maximum number of ADMM iterations |
| `abs_tol` | `1e-4` | Absolute primal/dual residual tolerance |
| `rel_tol` | `1e-3` | Relative primal/dual residual tolerance |
| `μ` | `10` | Residual ratio threshold for ρ adaptation |
| `τ` | `2` | Multiplicative factor for ρ adaptation |
| `slack_penalty` | `100` | Penalty for infeasibility slack variables |

## Complete Example — ADMM Sharing

```@example admm-sharing
using DistributedResourceOptimization

# Three flexible resources (e.g., heat pumps, battery, PV inverter)
# Each converts 10/15/10 kW input into three output types
flex1 = create_admm_flex_actor_one_to_many(10.0, [0.1,  0.5, -1.0])
flex2 = create_admm_flex_actor_one_to_many(15.0, [0.1,  0.5, -1.0])
flex3 = create_admm_flex_actor_one_to_many(10.0, [-1.0, 0.0,  1.0])

# Coordinator minimises weighted distance of Σxᵢ to target [-4, 0, 6]
# Priority weights [5, 1, 1] penalise deviations in sector 1 most heavily
coordinator = create_sharing_target_distance_admm_coordinator()
start_msg   = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))

start_coordinated_optimization([flex1, flex2, flex3], coordinator, start_msg)

println(result(flex1))
println(result(flex2))
println(result(flex3))
```

## Complete Example — ADMM Consensus

```@example admm-consensus
using DistributedResourceOptimization

# Two flex actors converge to a common 2-dimensional target [1.0, 2.0].
# Each actor has 10 kW input capacity with efficiency vector [0.6, 0.4].
actor1 = create_admm_flex_actor_one_to_many(10.0, [0.6, 0.4])
actor2 = create_admm_flex_actor_one_to_many(10.0, [0.6, 0.4])

coordinator = create_consensus_target_reach_admm_coordinator()
start_msg   = create_admm_start_consensus([1.0, 2.0])

start_coordinated_optimization([actor1, actor2], coordinator, start_msg)

println(result(actor1))
println(result(actor2))
```

!!! tip "Convergence Tips"
    If ADMM diverges or converges slowly, try:
    - Reducing `ρ` when primal residuals dominate
    - Increasing `ρ` when dual residuals dominate
    - Tightening `abs_tol` / `rel_tol` for higher precision
    - Increasing `max_iters` for complex problems

## See Also

- [`ADMMFlexActor`](@ref), [`create_admm_flex_actor_one_to_many`](@ref), [`result`](@ref)
- [`create_sharing_target_distance_admm_coordinator`](@ref), [`create_admm_start`](@ref), [`create_admm_sharing_data`](@ref)
- [`create_consensus_target_reach_admm_coordinator`](@ref), [`create_admm_start_consensus`](@ref)
- [Tutorial: Energy Dispatch with ADMM](../tutorials/energy_dispatch.md)
