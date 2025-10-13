# Distributed Resource Optimization for Julia

The package DistributedResourceOptimization.jl (DRO) aims to provide a collection of distributed optimization algorithms for optimizing distributed resources. The algorithms are implemented without considering one special communication technique or package. DRO provides abstract types and function interfaces to implement so-called carriers, which are able to execute the distributed algorithms asynchronous. All algorithms can also be used without carrier using fitting @spawn or @async statements.

Currently there are three tested algorithms:
* ADMM multi-value consensus such that the sum of all resp values equals a target vector
* ADMM sharing variant on flexibility providing resources
* COHDA, Combinatorial Optimization Heuristic for Distributed Agents, which minimizes the distance of schedule sums to a given target schedule

There is one carrier implemented:
* Mango.jl, agent framework for the simulation of distributed systems, DO provides roles to which the specific algorithms can be assigned to

Note that the package is highly work in progress. 

However, DRO is available on the general Julia registry, and can therfore be installed calling `]add DistributedResourceOptimization`.
