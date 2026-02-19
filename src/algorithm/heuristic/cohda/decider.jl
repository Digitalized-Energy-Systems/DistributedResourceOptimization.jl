
using Distributions

@kwdef struct LocalSearchDecider <: LocalDecider
    initial_schedule::Vector{Float64}
    corridors::Vector{Tuple{Float64,Float64}}
    local_performance::Function
    convergence_force_factor::Float64 = 0.1
    max_iterations::Int = 10
    sample_size_per_value::Int = 10
    distribution::Function = (low, up) -> Uniform(low, up)
end

function initial_schedule(decider::LocalSearchDecider, memory::WorkingMemory)
    return decider.initial_schedule
end

function local_performance_with_global_share(decider::LocalSearchDecider, schedule::Vector{Float64}, new_value::Float64, current_value::Float64, delta_to_target::Float64)
    return decider.local_performance(schedule) + decider.convergence_force_factor * ((new_value - current_value) + delta_to_target)
end

function find_new_value(decider::LocalSearchDecider, current_index::Int, current_best_schedule::Vector{Float64}, delta_to_target::Float64)
    corridor = decider.corridors[current_index]
    possible_values = rand(decider.distribution(corridor[1], corridor[2]), decider.sample_size_per_value)
    current_value = current_best_schedule[current_index]
    new_value_performance_tuples::Vector{Tuple{Float64,Float64}} = []
    new_value = nothing
    iteration = 1
    while length(possible_values) > 0 && iteration <= decider.max_iterations
        copy_bs = copy(current_best_schedule)
        random_index = ceil(Int, rand() * length(possible_values))
        new_value = possible_values[random_index]
        copy_bs[current_index] = new_value

        # we calculate the performance with a variable local performance share and a adaptive global performance share
        performance = local_performance_with_global_share(decider, copy_bs, new_value, current_value, delta_to_target)

        push!(new_value_performance_tuples, (new_value, performance))

        if length(new_value_performance_tuples) == 3
            # sort ascending by value
            sort!(new_value_performance_tuples)
            first = new_value_performance_tuples[1][1]
            second = new_value_performance_tuples[2][1]
            third = new_value_performance_tuples[3][1]

            # cut out undesirable parts of the whole vector
            if first > second > third
                possible_values = possible_values[possible_values.<second]
            elseif third > second > first
                possible_values = possible_values[possible_values.>second]
            elseif second > first > third || third > first > second
                possible_values = possible_values[possible_values.>max(third, second)]
                possible_values = possible_values[possible_values.<min(second, third)]
            end
        end
        iteration += 1
    end
    return new_value
end

function find_in_local_search_room(decider::LocalSearchDecider, current_best_schedule::Vector{Float64}, open_schedule::Vector{Float64})
    new_solution = []
    for (i, _) in enumerate(current_best_schedule)
        push!(new_solution, find_new_value(decider, i, current_best_schedule, open_schedule[i]))
    end
    return new_solution
end

function decide(cohda_data::COHDAAlgorithmData, decider::LocalSearchDecider, sysconfig::SystemConfig, candidate::SolutionCandidate)
    current_best_candidate = candidate
    current_best_schedule = candidate.schedules[cohda_data.participant_id, :]
    open_schedule = cohda_data.memory.target_params.schedule * cohda_data.memory.target_params.weights - sum(current_best_candidate.schedules, dims=1)

    new_best_schedule = find_in_local_search_room(decider, current_best_schedule, open_schedule)
    new_candidate = create_from_updated_sysconf(cohda_data.participant_id, sysconfig, new_best_schedule)

    schedule_choice_in_sysconfig = get(sysconfig.schedule_choices, cohda_data.participant_id, nothing)

    if isnothing(schedule_choice_in_sysconfig) || current_best_schedule != schedule_choice_in_sysconfig.schedule
        # update Sysconfig if your schedule in the current sysconf is different to the one in the candidate
        sysconfig.schedule_choices[cohda_data.participant_id] = ScheduleSelection(current_best_schedule, cohda_data.counter + 1)
        # update counter
        cohda_data.counter += 1
    end

    return sysconfig, new_candidate

end