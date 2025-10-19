export on_exchange_message, ScheduleSelection, SystemConfig, SolutionCandidate, TargetParams,
    WorkingMemory, COHDAAlgorithmData, create_cohda_start_message, create_cohda_participant

using AutoHashEquals

@auto_hash_equals struct ScheduleSelection
    schedule::Vector{Float64}
    counter::Int
end

@auto_hash_equals struct SystemConfig
    schedule_choices::Dict{Int,ScheduleSelection}
end

@auto_hash_equals mutable struct SolutionCandidate
    participant_id::Int
    schedules::Matrix{Float64}
    perf::Union{Float64,Nothing}
    present::Set{Int}
end

@auto_hash_equals struct TargetParams
    schedule::Vector{Float64}
    weights::Vector{Float64}
end

@auto_hash_equals mutable struct WorkingMemory
    target_params::Union{Nothing,TargetParams}
    system_config::SystemConfig
    solution_candidate::Union{Nothing,SolutionCandidate}
    additional_parameters::Dict{String,Any}
end
WorkingMemory(target_params, system_config, solution_candidate) = WorkingMemory(target_params, system_config, solution_candidate, Dict())

function cohda_default_performance(cluster_schedule::Matrix{Float64}, target_params::TargetParams)::Float64
    target_schedule = target_params.schedule
    weights = target_params.weights

    # we expect this input here
    sum_cs = sum(cluster_schedule, dims=1)  # sum for each interval
    diff = abs.(target_schedule' - sum_cs)  # deviation to the target schedule
    w_diff = diff * weights  # multiply with weight vector
    result = -sum(w_diff)
    return result
end

abstract type LocalDecider end

function initial_schedule(decider::LocalDecider, memory::WorkingMemory)
    throw("NotImplemented")
end

@kwdef struct DefaultLocalDecider <: LocalDecider
    schedule_provider::Function
    is_local_acceptable::Function = (_) -> true
end

function initial_schedule(local_decider::DefaultLocalDecider, memory::WorkingMemory)
    return local_decider.schedule_provider(memory)[0]
end

@kwdef mutable struct COHDAAlgorithmData <: DistributedAlgorithm
    participant_id::Int
    counter::Int = 0
    memory::WorkingMemory = WorkingMemory(nothing, SystemConfig(Dict()), nothing)
    performance_function::Function = cohda_default_performance
    decider::LocalDecider = DefaultLocalDecider()
end

function decide(cohda_data::COHDAAlgorithmData, decider::LocalDecider, sysconfig::SystemConfig, candidate::SolutionCandidate)
    throw("NotImplemented")
end

struct COHDAExchangeMessage
end

function merge_sysconfigs(sysconfig_i::SystemConfig, sysconfig_j::SystemConfig)
    sysconfig_i_schedules = sysconfig_i.schedule_choices
    sysconfig_j_schedules = sysconfig_j.schedule_choices
    key_set_i = keys(sysconfig_i_schedules)
    key_set_j = keys(sysconfig_j_schedules)

    new_sysconfig = Dict()
    modified = false

    for (i, a) in enumerate(sort(collect(union(key_set_i, key_set_j))))
        # An "a" might be in key_set_i, key_set_j or in both!
        if a in key_set_i && (!(a in key_set_j) || sysconfig_i_schedules[a].counter >= sysconfig_j_schedules[a].counter)
            # Use data of sysconfig_i
            schedule_selection = sysconfig_i_schedules[a]
        else
            # Use data of sysconfig_j
            schedule_selection = sysconfig_j_schedules[a]
            modified = true
        end

        new_sysconfig[a] = schedule_selection
    end

    if modified
        sysconf = SystemConfig(new_sysconfig)
    else
        sysconf = sysconfig_i
    end

    return sysconf
end

function merge_candidates(candidate_i::SolutionCandidate,
    candidate_j::Union{SolutionCandidate,Nothing},
    participant_id::Int,
    perf_func::Function,
    target_params::Union{TargetParams,Nothing})

    if isnothing(candidate_j)
        return candidate_i
    end
    keyset_i = candidate_i.present
    keyset_j = candidate_j.present
    candidate = candidate_i  # Default candidate is *i*

    if keyset_i < keyset_j
        # Use *j* if *K_i* is a true subset of *K_j*
        candidate = candidate_j
    elseif keyset_i == keyset_j
        # Compare the performance if the keyset is equal
        if isnothing(candidate_i.perf)
            candidate_i.perf = perf_func(candidate_i.schedules, target_params)
        end
        if isnothing(candidate_j.perf)
            candidate_j.perf = perf_func(candidate_j.schedules, target_params)
        end
        if candidate_j.perf > candidate_i.perf
            # Choose *j* if it performs better
            candidate = candidate_j
        elseif candidate_j.perf == candidate_i.perf
            # If both perform equally well, order them by name
            if candidate_j.participant_id < candidate_i.participant_id
                candidate = candidate_j
            end
        end
    elseif !isempty(setdiff(keyset_j, keyset_i))
        # If *candidate_j* shares some entries with *candidate_i*, update *candidate_i*
        both_sets = union(keyset_i, keyset_j)
        base_mat = zeros(maximum(both_sets), size(candidate.schedules, 2))
        for key in both_sets
            if key in keyset_i
                base_mat[key, :] = candidate_i.schedules[key, :]
            else
                base_mat[key, :] = candidate_j.schedules[key, :]
            end
        end
        # create new SolutionCandidate
        candidate = SolutionCandidate(participant_id, base_mat, nothing, both_sets)
    end
    return candidate
end

function perceive(cohda_data::COHDAAlgorithmData, working_memories::Vector{WorkingMemory})::Tuple{SystemConfig,SolutionCandidate}
    current_sysconfig = nothing
    current_candidate = nothing
    own_id = cohda_data.participant_id
    own_memory = cohda_data.memory
    for new_wm in working_memories
        if isnothing(cohda_data.memory.target_params)
            # get target parameters if not known
            own_memory.target_params = new_wm.target_params
        end
        if isnothing(current_sysconfig)
            if !haskey(own_memory.system_config.schedule_choices, own_id)
                # if you have not yet selected any schedule in the sysconfig, choose any to start with
                schedule_choices = own_memory.system_config.schedule_choices
                schedule_choices[own_id] = ScheduleSelection(
                    cohda_data.decider.schedule_provider(own_memory)[1], cohda_data.counter + 1)
                cohda_data.counter += 1
                # we need to create a new instance of SystemConfig so the updates are
                # recognized in handle_cohda_msgs()
                current_sysconfig = SystemConfig(schedule_choices)
            else
                current_sysconfig = own_memory.system_config
            end
        end
        if isnothing(current_candidate)
            if isnothing(own_memory.solution_candidate) || !(own_id in own_memory.solution_candidate.present)
                # if you have not yet selected any schedule in the sysconfig, choose any to start with
                own_schedule = cohda_data.decider.schedule_provider(own_memory)[1]
                base_mat = zeros(own_id, length(own_schedule))
                own_memory.solution_candidate = SolutionCandidate(own_id, base_mat, nothing, Set([own_id]))
                schedules = own_memory.solution_candidate.schedules
                schedules[own_id, :] = own_schedule
                current_candidate = own_memory.solution_candidate
            else
                current_candidate = own_memory.solution_candidate
            end
        end

        new_sysconf = new_wm.system_config
        new_candidate = new_wm.solution_candidate

        # Merge new information into current_sysconfig and current_candidate
        current_sysconfig = merge_sysconfigs(current_sysconfig, new_sysconf)
        current_candidate = merge_candidates(current_candidate, new_candidate, own_id, cohda_data.performance_function, own_memory.target_params)
    end

    return current_sysconfig, current_candidate
end

function create_from_updated_sysconf(participant_id::Int, sysconfig::SystemConfig, new_schedule::Vector)::SolutionCandidate
    base_mat = zeros(maximum(keys(sysconfig.schedule_choices)), length(new_schedule))
    for (id::Int, choice::ScheduleSelection) in sysconfig.schedule_choices
        base_mat[id, :] = choice.schedule
    end
    base_mat[participant_id, :] = new_schedule
    return SolutionCandidate(participant_id, base_mat, nothing, keys(sysconfig.schedule_choices))
end

function decide(cohda_data::COHDAAlgorithmData, decider::DefaultLocalDecider, sysconfig::SystemConfig, candidate::SolutionCandidate)
    possible_schedules = decider.schedule_provider(cohda_data.memory)
    current_best_candidate = candidate
    if isnothing(current_best_candidate.perf)
        current_best_candidate.perf = cohda_data.performance_function(current_best_candidate.schedules, cohda_data.memory.target_params)
    end
    current_best_schedule = candidate.schedules[cohda_data.participant_id, :]
    for schedule in possible_schedules
        if decider.is_local_acceptable(schedule)
            # create new candidate from sysconfig
            new_candidate = create_from_updated_sysconf(cohda_data.participant_id, sysconfig, schedule)
            new_performance = cohda_data.performance_function(
                new_candidate.schedules, cohda_data.memory.target_params
            )
            # only keep new candidates that perform better than the current one
            if new_performance > current_best_candidate.perf
                new_candidate.perf = new_performance
                current_best_candidate = new_candidate
                current_best_schedule = schedule
            end
        end
    end

    schedule_choice_in_sysconfig = get(sysconfig.schedule_choices, cohda_data.participant_id, nothing)

    if isnothing(schedule_choice_in_sysconfig) || current_best_schedule != schedule_choice_in_sysconfig.schedule
        # update Sysconfig if your schedule in the current sysconf is different to the one in the candidate
        sysconfig.schedule_choices[cohda_data.participant_id] = ScheduleSelection(current_best_schedule, cohda_data.counter + 1)
        # update counter
        cohda_data.counter += 1
    end

    return sysconfig, current_best_candidate
end

function act(cohda_data::COHDAAlgorithmData, new_sysconfig::SystemConfig, new_candidate::SolutionCandidate)::WorkingMemory
    cohda_data.memory.system_config = new_sysconfig
    cohda_data.memory.solution_candidate = new_candidate
    return cohda_data.memory
end

function process_exchange_message(algorithm_data::COHDAAlgorithmData, messages::Vector{WorkingMemory}, carrier::Carrier)
    # store old wm
    old_sysconf = algorithm_data.memory.system_config
    old_candidate = algorithm_data.memory.solution_candidate

    # perceive 
    sysconf, candidate = perceive(algorithm_data, messages)

    # decide
    if sysconf != old_sysconf || candidate != old_candidate
        # something changed in perceive so we do decide and act
        sysconf, candidate = decide(algorithm_data, algorithm_data.decider, sysconf, candidate)
        # act
        for other in others(carrier, "$(algorithm_data.participant_id)")
            wm = act(algorithm_data, sysconf, candidate)
            send_to_other(carrier, wm, other)
        end
    end
end

function on_exchange_message(algorithm_data::COHDAAlgorithmData, carrier::Carrier, message::WorkingMemory, meta::Any)
    process_exchange_message(algorithm_data, [message], carrier)
    return true
end

function create_cohda_start_message(target_schedule::Vector{Float64}, weights::Union{Vector{Float64},Nothing}=nothing)::WorkingMemory
    if isnothing(weights)
        weights = ones(length(target_schedule))
    end
    return WorkingMemory(
        TargetParams(target_schedule, weights),
        SystemConfig(Dict()),
        nothing
    )
end

function create_cohda_participant(participant_id::Int, schedule_set::Vector{Vector{Float64}})::COHDAAlgorithmData
    return create_cohda_participant(participant_id, (_) -> schedule_set)
end

function create_cohda_participant(participant_id::Int,
    schedule_provider::Function,
    performance_function::Function=cohda_default_performance)::COHDAAlgorithmData

    return create_cohda_participant_with_decider(participant_id,
        DefaultLocalDecider(schedule_provider=schedule_provider),
        performance_function)
end

function create_cohda_participant_with_decider(participant_id::Int,
    decider::LocalDecider,
    performance_function::Function=cohda_default_performance)::COHDAAlgorithmData

    return COHDAAlgorithmData(participant_id=participant_id,
        performance_function=performance_function,
        decider=decider)
end


