export LinearCostEconomicDispatchDiffusionActor, ReservoirStorageDiffusionActor

@kwdef mutable struct LinearCostEconomicDispatchDiffusionActor <: DiffusionActor
    #cost::Real.value_curve.function_data.proportional_term
    cost::Real
    P_max::Real
    ϵ::Real = 0.1
    P_min::Real = 0
    N_guess::Int = 10
    P::Vector{Float64} = [0]
end

function DistributedResourceOptimization.gradient_term(actor::LinearCostEconomicDispatchDiffusionActor, λ::Vector{<:Real}, P_target::Vector{<:Real})
    # linearized inverted quadratic cost function aP¹ + bP minus the target

    actor.P = clamp.((λ .- actor.cost) ./ actor.ϵ, actor.P_min, actor.P_max)
    term = actor.P .- P_target ./ actor.N_guess
    return term
end


"""
Actor for EnergyReservoirStorage optimization
Optimizes charge/discharge schedule based on time-varying λ(t)

The storage actor:
- Wants to discharge (positive power) when λ(t) > discharge_cost
- Wants to charge (negative power) when λ(t) < charge_cost
- Respects energy capacity constraints (E_max)
- Respects power limits (P_charge_max, P_discharge_max)
- Respects charge/discharge efficiencies (η_charge, η_discharge)
- Maintains energy balance between initial and final states
- Respects SOC limits (soc_min, soc_max)
"""
@kwdef mutable struct ReservoirStorageDiffusionActor <: DiffusionActor
    # Storage parameters
    E_max::Real              # Maximum energy capacity (MWh)
    P_charge_max::Real       # Maximum charging power (MW)
    P_discharge_max::Real    # Maximum discharging power (MW)
    η_charge::Real = 0.95    # Charging efficiency
    η_discharge::Real = 0.95 # Discharging efficiency
    E_initial::Real = 0.5    # Initial energy level (fraction of E_max)
    E_final::Real = 0.5      # Final energy level (fraction of E_max)
    soc_min::Real = 0.0      # Minimum state of charge (fraction)
    soc_max::Real = 1.0      # Maximum state of charge (fraction)

    # Cost parameters
    charge_cost::Real = 0.0   # Marginal cost for charging
    discharge_cost::Real = 0.0 # Marginal benefit for discharging (can be revenue)

    ϵ::Real = 0.1
    N_guess::Int = 10

    # State variables
    P::Vector{Float64} = [0]   # Power schedule, positive = discharge, negative = charge
    E::Vector{Float64} = [0]   # Energy state
end

function DistributedResourceOptimization.gradient_term(actor::ReservoirStorageDiffusionActor, λ::Vector{<:Real}, P_target::Vector{<:Real})
    T = length(λ)
    
    # Initialize energy state vector if needed
    if length(actor.E) != T
        actor.E = zeros(T)
    end
    
    # Step 1: Compute optimal power at each time step based on local λ
    # Storage wants to discharge when λ > discharge_cost + charge_cost, charge when λ < charge_cost
    for t in 1:T
        λ_t = λ[t]
        
        # Determine desired action based on price difference
        if λ_t > actor.discharge_cost + actor.charge_cost
            # Discharging is beneficial
            # Optimal discharge power based on λ
            desired_P = min((λ_t - actor.charge_cost) / actor.ϵ, actor.P_discharge_max)
            actor.P[t] = desired_P
        elseif λ_t < actor.charge_cost
            # Charging is beneficial (negative power for charging)
            desired_P = max((λ_t - actor.charge_cost) / actor.ϵ, -actor.P_charge_max)
            actor.P[t] = desired_P
        else
            # Stay idle
            actor.P[t] = 0.0
        end
    end
    
    # Step 2: Adjust power schedule to respect energy constraints
    # Compute cumulative energy with storage dynamics
    actor.E[1] = actor.E_initial * actor.E_max
    for t in 2:T
        # E[t] = E[t-1] - P[t-1]*dt (assuming dt=1 hour)
        if actor.P[t-1] >= 0
            # Discharging: energy decreases
            actor.E[t] = actor.E[t-1] - actor.P[t-1] / actor.η_discharge
        else
            # Charging: energy increases
            actor.E[t] = actor.E[t-1] - actor.P[t-1] * actor.η_charge
        end
    end
    
    # Step 3: Clip energy to SOC limits
    E_min = actor.soc_min * actor.E_max
    E_max_limit = actor.soc_max * actor.E_max
    actor.E = clamp.(actor.E, E_min, E_max_limit)
    # Step 4: Backward pass to ensure final energy constraint
    # Adjust power to meet final energy target
    E_target_final = actor.E_final * actor.E_max
    E_error = E_target_final - actor.E[T]
    
    if abs(E_error) > 0.001  # Small tolerance
        # Distribute error across all time steps
        # Simple approach: scale power schedule
        total_energy_change = sum(actor.P)
        
        if abs(total_energy_change) > 0.001
            scale_factor = 1.0 + E_error / total_energy_change
            actor.P = actor.P .* scale_factor
        else
            # If no net energy flow, add small charge/discharge to meet target
            adjustment = E_error / T
            actor.P = actor.P .+ adjustment
        end
    end
    

    # Step 5: Re-clamp power limits AND SOC limits
    actor.P = clamp.(actor.P, -actor.P_charge_max, actor.P_discharge_max)
    

    # Step 6: Ensure SOC limits are respected after adjustment
    for t in 1:T
        soc_t = actor.E[t] / actor.E_max
        if actor.P[t] > 0  # Discharging


            max_discharge = min(actor.P_discharge_max, (soc_t - actor.soc_min) * actor.E_max * actor.η_discharge)
            actor.P[t] = min(actor.P[t], max_discharge)
        else  # Charging

            max_charge = min(actor.P_charge_max, (actor.soc_max - soc_t) * actor.E_max / actor.η_charge)
            actor.P[t] = max(actor.P[t], -max_charge)
        end
    end
    
    # Compute gradient term
    term = actor.P .- P_target ./ actor.N_guess
    return term
end
