COHDA is a distributed optimization heuristic, which solves MC-COP (Multiple Choice Combinatorial Optimization Problem). 

COHDA minimizes the distance of the sum of a set of schedules (distributedly chosen) to a target vector.

```math
\begin{equation}
  \begin{split}
      &\underset{x_{\rm i,j}}{\text{max}}~\left(-\lVert T - \sum_{i=1}^{N}\sum_{j=1}^{M} (U_{\rm i,j}\cdot x_{\rm i,j})\rVert_1\right)\\
      &\text{with } \sum_{j=1}^{M}x_{{\rm i,j}} = 1\\
      &x_{{\rm i,j}}\in\left\{0,\,1\right\},~i=1,\,\dots,\,N,~j=1,\,\dots,\,M.
  \end{split}
\end{equation}
```

To use COHDA [`create_cohda_participant`](@ref) and [`create_cohda_start_message`](@ref) can be used.