
# Distributed Optimization for Julia

The package DistributedOptimization.jl (DO) aims to provide a collection of distributed optimization algorithms. The algorithms are implemented without considering one special communication technique or package. DO provides abstract types and function interfaces to implement so-called carriers, which are able to execute the distributed algorithms asynchronous. All algorithms can also be used without carrier using fitting @spawn or @async statements.

Currently there are two tested algorithms:
* ADMM multi-value consensus such that the sum of all resp values equals a target vector
* COHDA, Combinatorial Optimization Heuristic for Distributed Agents, which minimizes the distance of schedule sums to a given target schedule

There is one carrier implemented:
* Mango.jl, agent framework for the simulation of distributed systems, DO provides roles to which the specific algorithms can be assigned to

Note that the package is highly work in progress.