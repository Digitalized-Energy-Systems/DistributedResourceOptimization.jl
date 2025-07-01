export ADMMStart, ADMMAnswer, ADMMAnswer, ADMMGlobalActor, ADMMGlobalObjective, ADMMGenericCoordinator

struct ADMMStart
    data::Any
    solution_length::Int
end

struct ADMMMessage 
    v::Vector{Float64}
    ρ::Float64
end

struct ADMMAnswer
    x::Vector{Float64}
end

abstract type ADMMGlobalActor end

function z_update(actor::ADMMGlobalActor, x, u, z, ρ, N)
    throw("NotImplemented")
end

function u_update(actor::ADMMGlobalActor, x, u, z, ρ, N)
    throw("NotImplemented")
end

function init_z(actor::ADMMGlobalActor, n::Int, m::Int)
    throw("NotImplemented")
end

function init_u(actor::ADMMGlobalActor, n::Int, m::Int)
    throw("NotImplemented")
end

function actor_correction(actor::ADMMGlobalActor, x, z, u, i)
    throw("NotImplemented")
end

function primal_residual(actor::ADMMGlobalActor, x, z)
    throw("NotImplemented")
end

abstract type ADMMGlobalObjective end

function objective(global_objective::ADMMGlobalObjective, x, u, z, N) 
    throw("NotImplemented")
end

@kwdef struct ADMMGenericCoordinator <: Coordinator
    global_actor::ADMMGlobalActor
    ρ::Float64 = 1.0 
    max_iters::Int64 = 100
    slack_penalty::Int64 = 100
    abs_tol::Float64 = 1e-4
    rel_tol::Float64 = 1e-3
    μ::Real = 10
    τ::Real = 2
end

# ADMM solver
function _start_coordinator(admm::ADMMGenericCoordinator, carrier::Carrier, input::Any, m::Int)
    ρ = admm.ρ
    max_iters = admm.max_iters
    abs_tol = admm.abs_tol
    rel_tol = admm.rel_tol
    n = length(others(carrier, "coordinator"))
    μ = admm.μ
    τ = admm.τ

    # Initialize
    x = [zeros(m) for i in 1:n]
    z = init_z(admm.global_actor, n, m)
    u = init_u(admm.global_actor, n, m)

    for k in 1:max_iters
        # 1. Local x-updates (in parallel)
        awaitables = []
        # send all async and get awaitable
        for (i,addr) in enumerate(others(carrier, "c"))
            push!(awaitables, send_awaitable(carrier, ADMMMessage(actor_correction(admm.global_actor, x, z, u, i), ρ), addr))
        end
        # await all awaitables and update x
        for (i,awaitable) in enumerate(awaitables)
            x[i] = wait(carrier, awaitable).x
        end

        # 2. Global z-update
        z_old = deepcopy(z)

        z = z_update(admm.global_actor, input, x, u, z, ρ, n)
        u = u_update(admm.global_actor, x, u, z, ρ, n)

        # 4. Check convergence
        # primal residual: max over i of ||x_i - z_i||
        r_norm = primal_residual(admm.global_actor, x, z)
        # dual residual: ρ * max over i of ||z_i - z_old_i||
        s_norm = ρ * maximum(norm.(z .- z_old))
        # tolerances
        ϵ_pri = sqrt(m*n)*abs_tol + rel_tol*max(maximum(norm.(x)), maximum(norm.(z)))
        ϵ_dual = sqrt(m*n)*abs_tol + rel_tol*maximum(norm.(u))
        if r_norm < ϵ_pri && s_norm < ϵ_dual
            @warn "Converged in $k iterations."
            break
        end
        
        # Varying penalty paramter according to B. S. He, H. Yang, and S. L. Wang, “Alternating direction method with self
        # adaptive penalty parameters for monotone variational inequalities,”
        if r_norm > μ * s_norm
            ρ = ρ * τ
        elseif s_norm > μ * r_norm
            ρ = ρ / τ
        end
        
        if k == max_iters
            @warn "Reached max iterations ($max_iters) without full convergence."
            throw("ADMM not converged $x, $u")
        end
    end
    return x, z, u
end

function start_optimization(coordinator::ADMMGenericCoordinator, carrier::Carrier, start_data::ADMMStart, meta::Any)
    x,_,_ = _start_coordinator(coordinator, carrier, start_data.data, start_data.solution_length)
    return x
end