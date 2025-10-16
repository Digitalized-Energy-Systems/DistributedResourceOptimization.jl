In DRO.jl every ADMM optimization consists of two components, the ADMM problem form itself, and the local model, which determines local constraints and objectives.

# Problem Form

## Consensus

The single global variable consensus form can be written as

```math
\begin{equation}
\begin{split}
\min_{\{x_i\},\,z}\;\; \sum_{i=1}^N f_i(x_i) \\
\quad\text{s.t.}\quad x_i = z,\;\; i=1,\dots,N,
\end{split}
\end{equation}
```

where ``f_i`` is the local objective of agent ``i``, ``x_i`` the decision variable of this agent.

With the dual variable ``u`` and the penalty ``\rho`` the update iteration reads.

```math
\begin{align}
x_i^{k+1} 
&= \arg\min_{x_i} \;
f_i(x_i) 
+ \frac{\rho}{2}\big\| x_i - \big(z^k - u_i^k \big) \big\|_2^2
\\
z^{k+1} 
&= \arg\min_{z} \;
g(z) + \frac{N \rho}{2}\left\| 
z - \Big( \bar{x}^{k+1} + \bar{u}^k \Big) 
\right\|_2^2 \\
u_i^{k+1} 
&= u_i^k + x_i^{k+1} - z^{k+1}
\end{align}
```

To instantiate a coordinator for the sharing form, use [`create_consensus_target_reach_admm_coordinator`](@ref). To start the neotiation you need to use [`create_admm_start_consensus`](@ref).


## Sharing

Take the sharing problem:

```math
\begin{equation}
\begin{split}
\min_{\{x_i\},\,z}\;\; \sum_{i=1}^N f_i(x_i) \;+\; g(z)\\
\quad\text{s.t.}\quad \sum_{i=1}^N x_i = z,\;\; i=1,\dots,N,
\end{split}
\end{equation}
```

where ``f_i`` is the local objective of agent ``i``, ``x_i`` the decision variable of this agent, and ``g`` the global objective.

With the dual variable ``u`` and the penalty ``\rho`` the generic update iteration reads.

```math
\begin{align}
x_i^{k+1} 
  &= \arg\min_{x_i}\;
     f_i(x_i) + \tfrac{\rho}{2}\,\big\lVert x_i - (z^k - u^k) \big\rVert_2^2,
    \\
     &i=1,\dots,N, 
     \\[6pt]
z^{k+1} 
  &= \arg\min_{z}\;
     g(N\cdot z) + \tfrac{N\rho}{2}\,\big\lVert z - \bar{x}^{\,k+1} - u^k \big\rVert_2^2,
     \\
\bar{x}^{\,k+1} 
  &= \tfrac{1}{N}\sum_{i=1}^N x_i^{k+1},
     \\[6pt]
u^{k+1} 
  &= u^k + \bar{x}^{\,k+1} - z^{k+1}. 
     
\end{align}
```

To instantiate a coordinator for the sharing form, use [`create_sharing_admm_coordinator`](@ref). To start the negotiation you can use [`create_admm_start`](@ref).

# Local Models

## Flexibility Actor

Each local actor `ì`` has some flexibility of ``m`` resources and a decision on the provided flexibility ``x_i``. The decision is constrained by
* lower and upper bounds ``l_i \leq x_i \leq u_i``
* coupling constraints ``C_i x_i\leq d_i``
* linear penalites ``S_i`` for priorization

To instantiate a flexibility actor use [`create_admm_flex_actor_one_to_many`](@ref).