# DistributedResourceOptimization.jl

**DRO** is a Julia package for distributed optimization of resources across decentralized systems.
It provides a clean collection of algorithms — ADMM, COHDA, and Averaging Consensus — paired with a
carrier abstraction that decouples algorithm logic from the underlying communication layer.

```@raw html
<div class="feature-grid">
  <div class="feature-card">
    <div class="feature-title">Multiple Algorithms</div>
    <div class="feature-desc">ADMM (Sharing &amp; Consensus), COHDA heuristic, and Averaging Consensus — ready to use out of the box.</div>
  </div>
  <div class="feature-card">
    <div class="feature-title">Pluggable Carriers</div>
    <div class="feature-desc">Swap communication backends without touching algorithm code. Built-in SimpleCarrier or full Mango.jl agent framework.</div>
  </div>
  <div class="feature-card">
    <div class="feature-title">Async by Design</div>
    <div class="feature-desc">Algorithms communicate via asynchronous message passing, built on Julia's native task system.</div>
  </div>
  <div class="feature-card">
    <div class="feature-title">Research-Ready</div>
    <div class="feature-desc">Mathematical formulations with configurable parameters. Easily extend with custom algorithms and carriers.</div>
  </div>
</div>
```

## Installation

DRO is registered in the Julia General registry. Install it with:

```julia
using Pkg
Pkg.add("DistributedResourceOptimization")
```

## Quick Example

The simplest way to run a distributed optimization is using the express API — no carrier setup required:

```@example index-cohda
using DistributedResourceOptimization

# COHDA: each participant selects one schedule to minimize distance to a target
actor_one = create_cohda_participant(1, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])
actor_two = create_cohda_participant(2, [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0]])

target = create_cohda_start_message([1.2, 2.0, 3.0])

wait(start_distributed_optimization([actor_one, actor_two], target))
```

For coordinated algorithms like ADMM, a coordinator manages the global update:

```@example index-admm
using DistributedResourceOptimization

# Three flexible resources sharing capacity to reach a target
flex_actor1 = create_admm_flex_actor_one_to_many(10, [0.1, 0.5, -1.0])
flex_actor2 = create_admm_flex_actor_one_to_many(15, [0.1, 0.5, -1.0])
flex_actor3 = create_admm_flex_actor_one_to_many(10, [-1.0, 0.0,  1.0])

coordinator = create_sharing_target_distance_admm_coordinator()
start_msg   = create_admm_start(create_admm_sharing_data([-4.0, 0.0, 6.0], [5, 1, 1]))

start_coordinated_optimization([flex_actor1, flex_actor2, flex_actor3], coordinator, start_msg)
```

## What's Included

| Category | Name | Description |
|----------|------|-------------|
| **Algorithm** | [ADMM Sharing](algorithms/admm.md) | Distributed resource allocation with a shared global variable |
| **Algorithm** | [ADMM Consensus](algorithms/admm.md) | Consensus towards a common target value |
| **Algorithm** | [COHDA](algorithms/cohda.md) | Combinatorial heuristic for schedule selection |
| **Algorithm** | [Averaging Consensus](algorithms/consensus.md) | Gossip-based averaging with gradient terms |
| **Carrier** | [SimpleCarrier](carrier/simple.md) | Lightweight in-process carrier for prototyping and testing |
| **Carrier** | [MangoCarrier](carrier/mango.md) | Full agent-based carrier via [Mango.jl](https://github.com/OFFIS-DAI/Mango.jl) |

## Navigation Guide

```@raw html
<div class="nav-grid">
  <a class="nav-card" href="getting_started/">
    <div class="nav-title">Getting Started</div>
    <div class="nav-desc">Installation, first steps, and choosing an algorithm</div>
  </a>
  <a class="nav-card" href="algorithms/admm/">
    <div class="nav-title">Algorithms</div>
    <div class="nav-desc">Mathematical background and usage for each algorithm</div>
  </a>
  <a class="nav-card" href="tutorials/energy_dispatch/">
    <div class="nav-title">Tutorials</div>
    <div class="nav-desc">End-to-end walkthroughs for concrete use cases</div>
  </a>
  <a class="nav-card" href="howtos/custom_algorithm/">
    <div class="nav-title">How-To Guides</div>
    <div class="nav-desc">Implement your own algorithms and carriers</div>
  </a>
  <a class="nav-card" href="carrier/simple/">
    <div class="nav-title">Carriers</div>
    <div class="nav-desc">Choose and configure a communication backend</div>
  </a>
  <a class="nav-card" href="api/">
    <div class="nav-title">API Reference</div>
    <div class="nav-desc">Complete documentation of all exported functions and types</div>
  </a>
</div>
```

!!! note "Work in Progress"
    DRO is under active development. APIs may change between minor versions.
    Feedback and contributions are welcome on [GitHub](https://github.com/Digitalized-Energy-Systems/DistributedResourceOptimization.jl).
