using JuMP
using OSQP

# Define an actor with bounds and coupling constraints
struct Actor
    l::Vector{Float64}       # lower bounds
    u::Vector{Float64}       # upper bounds
    C::Matrix{Float64}       # coupling matrix
    d::Vector{Float64}       # coupling RHS
end

# Projection onto local feasible set via QP
function project_C(actor::Actor, v::Vector{Float64})
    m = length(v)
    model = Model(OSQP.Optimizer)
    set_silent(model)
    @variable(model, x[1:m])
    @objective(model, Min, sum((x[i] - v[i])^2 for i in 1:m))
    @constraint(model, [i=1:m], actor.l[i] <= x[i] <= actor.u[i])
    @constraint(model, actor.C * x .<= actor.d)
    optimize!(model)
    return value.(x)
end

# Async gossip for vector quantities
function gossip_async(vars::Vector{Vector{Float64}}, neighbors::Vector{Vector{Int}}, rounds::Int)
    n = length(vars)
    z = deepcopy(vars)
    for r in 1:rounds
        z_old = deepcopy(z)
        z_new = [zeros(length(z[1])) for _ in 1:n]
        @sync for i in 1:n
            @async begin
                sumv = z_old[i]
                for j in neighbors[i]
                    sumv .+= z_old[j]
                end
                z_new[i] = sumv ./ (length(neighbors[i]) + 1)
            end
        end
        z = z_new
    end
    return z
end

# Fully peer-to-peer distributed algorithm via projected gradient + consensus
function dist_peer_to_peer(actors::Vector{Actor}, T::Vector{Float64};
                           α=0.1,    # step for x-update
                           β=0.1,    # dual ascent step
                           neigh_iters=5,
                           max_iters=500,
                           tol=1e-3)
    n = length(actors)
    m = length(T)
    # initial values
    x = [zeros(m) for _ in 1:n]
    λ = [zeros(m) for _ in 1:n]  # local price estimates
    # simple neighbors: ring topology
    neighbors = [[i==1 ? 2 : i-1, i==n ? 1 : i+1] for i in 1:n]
    # per-node target share
    T_share = T ./ n

    for k in 1:max_iters
        # 1. local projection step: x_i = proj_C( x_i - α*λ_i )
        @sync for i in 1:n
            @async x[i] = project_C(actors[i], x[i] .- α .* λ[i])
        end
        # 2. dual ascent: λ_i = λ_i + β*( x_i - T_share )
        for i in 1:n
            λ[i] .+= β .* (x[i] .- T_share)
        end
        # 3. consensus on λ estimates
        λ = gossip_async(λ, neighbors, neigh_iters)
        # 4. check convergence: norm of constraint violation
        violation = maximum(norm.(sum(x) .- T))
        if violation < tol
            println("Converged in \$k iterations with violation \$violation.")
            break
        end
        if k == max_iters
            println("Max iters reached. Final violation: \$violation.")
        end
    end
    return x, λ
end

# Example usage
m = 2
# CHP actor
C_chp = [1.0 1.0;
         -2/3 1.0;
          2/3 -1.0]
d_chp = [10.0; 0.0; 0.0]
l_chp = [0.0,0.0]
u_chp = [6.0,4.0]
# Power-only actor
C_pow = [1.0 0.0]
d_pow = [5.0]
l_pow = [0.0,0.0]
u_pow = [5.0,0.0]
actors = [Actor(l_chp,u_chp,C_chp,d_chp), Actor(l_pow,u_pow,C_pow,d_pow)]
T = [8.0, 3.0]
# run fully peer-to-peer
x_sol, lambda_sol = dist_peer_to_peer(actors, T)
println("x solutions: ", x_sol)
println("lambda consensus: ", lambda_sol)
