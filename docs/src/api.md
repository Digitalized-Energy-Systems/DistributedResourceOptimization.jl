# API Reference

Complete documentation for all exported types and functions.

## Core Abstractions

### Algorithm Interface

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/core.jl"]
```

### Carrier Interface

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["carrier/core.jl"]
```

---

## Carriers

### SimpleCarrier

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["carrier/simple.jl"]
```

### MangoCarrier

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["carrier/mango.jl"]
```

---

## Algorithms

### ADMM — Core

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/admm/core.jl"]
```

### ADMM — Sharing Variant

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/admm/sharing_admm.jl"]
```

### ADMM — Consensus Variant

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/admm/consensus_admm.jl"]
```

### ADMM — Flexibility Actor

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/admm/flex_actor.jl"]
```

### COHDA

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/heuristic/cohda/core.jl",
           "algorithm/heuristic/cohda/decider.jl"]
```

### Averaging Consensus

```@autodocs
Modules = [DistributedResourceOptimization]
Private = false
Pages   = ["algorithm/consensus/averaging.jl",
           "algorithm/consensus/economic_dispatch.jl"]
```
