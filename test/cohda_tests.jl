using Test
using DistributedOptimization

import DistributedOptimization: cohda_default_performance, merge_sysconfigs, merge_candidates,
    perceive, decide

@testset "TestCohdaDefaultPerformance" begin
    mat = [1.0 2.0 3.0; 1.0 2.0 3.0; 1.0 1.0 2.0]
    target = [3.0, 3.0, 5.0]
    weights = [1.0, 1.0, 1.0]
    perf = cohda_default_performance(mat, TargetParams(target, weights))

    @test perf == -5

    mat = [1.0 2.0 3.0; 1.0 2.0 3.0; 1.0 1.0 2.0]
    target = [3.0, 3.0, 5.0]
    weights = [1.0, 2.0, 3.0]
    perf = cohda_default_performance(mat, TargetParams(target, weights))

    @test perf == -13
end

MERGE_SYSCONFIGS_PARAM_LIST = [
    (Dict(1 => ([1, 2], 42), 2 => ([4, 2], 4)),
        Dict(1 => ([10, 20], 45), 2 => ([40, 20], 5)),
        Dict(1 => ([10, 20], 45), 2 => ([40, 20], 5))), (Dict(1 => ([1, 2], 42)),
        Dict(1 => ([10, 20], 40), 2 => ([40, 20], 5)),
        Dict(1 => ([1, 2], 42), 2 => ([40, 20], 5))), (Dict(1 => ([1, 2], 42)),
        Dict(2 => ([40, 20], 5)),
        Dict(1 => ([1, 2], 42), 2 => ([40, 20], 5))), (Dict(1 => ([1, 2], 42)),
        Dict(1 => ([40, 20], 5)),
        Dict(1 => ([1, 2], 42))), (Dict(1 => ([1, 2], 42), 2 => ([40, 20], 5)),
        Dict(1 => ([1, 2], 42), 2 => ([40, 20], 5)),
        Dict(1 => ([1, 2], 42), 2 => ([40, 20], 5))),
]

@testset "TestMergeSysconfigs" for (schedules_i, schedules_j, expected_schedules) in MERGE_SYSCONFIGS_PARAM_LIST
    schedule_selections_i = Dict()
    schedule_selections_j = Dict()
    expected_selections = Dict()

    for (part_id, (schedule, counter)) in schedules_i
        schedule_selections_i[part_id] = ScheduleSelection(schedule, counter)
    end
    for (part_id, (schedule, counter)) in schedules_j
        schedule_selections_j[part_id] = ScheduleSelection(schedule, counter)
    end
    for (part_id, (schedule, counter)) in expected_schedules
        expected_selections[part_id] = ScheduleSelection(schedule, counter)
    end
    sysconfig_i = SystemConfig(schedule_selections_i)
    sysconfig_j = SystemConfig(schedule_selections_j)
    expected_sysconfig = SystemConfig(expected_selections)

    merged_sysconfig = merge_sysconfigs(sysconfig_i, sysconfig_j)
    @test merged_sysconfig == expected_sysconfig
    @test (sysconfig_i == merged_sysconfig) == (sysconfig_i === merged_sysconfig)

end

MERGE_CANDIDATES_PARAM_LIST = [
    ([1 2; 4 2], [1, 2], 1, 0.5, [10 20; 40 20], [1, 2], 2, 0.5, 3,
        [1 2; 4 2], 1, 0.5),
    ([1 2; 4 2], [1, 2], 1, 0.4, [10 20; 40 20], [1, 2], 2, 0.5, 3,
        [10 20; 40 20], 2, 0.5),
    ([1 2; 4 2], [1, 2], 1, 0.4, [0 0; 40 20], [1], 2, 0.5, 3,
        [1 2; 4 2], 1, 0.4),
    ([1 2; 0 0], [1], 1, 0.4, [10 20; 40 20], [1, 2], 2, 0.5, 3,
        [10 20; 40 20], 2, 0.5),
    ([1 2; 0 0], [1], 1, 0.4, [0 0; 40 20], [2], 2, 0.5, 3, [1 2; 40 20], 3, nothing),
]

@testset "TestMergeCandidates" for (schedules_i, present_i, part_id_i, perf_i,
    schedules_j, present_j, part_id_j, perf_j,
    own_id, expected_schedules, expected_part_id, expected_perf) in MERGE_CANDIDATES_PARAM_LIST

    candidate_i = SolutionCandidate(part_id_i, schedules_i, perf_i, Set(present_i))
    candidate_j = SolutionCandidate(part_id_j, schedules_j, perf_j, Set(present_j))

    expected_candidate = SolutionCandidate(expected_part_id, expected_schedules, expected_perf, Set([1, 2]))

    function sum_schedule(cluster_schedule, _)
        return sum(sum(values(cluster_schedule)))
    end

    @test merge_candidates(candidate_i, candidate_j, own_id, sum_schedule, nothing) == expected_candidate
end

@testset "TestSimplePerceiveStart" begin
    cohda = create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3]])
    input_wm = WorkingMemory(
        TargetParams([1, 2, 3], [1, 1, 1]),
        SystemConfig(Dict()),
        nothing
    )
    perceive(cohda, [input_wm])

    @test cohda.memory.target_params == TargetParams([1, 2, 3], [1, 1, 1])
end

@testset "TestSelectionMultiplePerceiveDecide" begin
    cohda = create_cohda_participant(1, [[0.0, 1, 2], [1, 2, 3], [1, 1, 1], [4, 2, 3]])
    init_wm = WorkingMemory(
        TargetParams([1, 2, 1], [1, 1, 1]),
        SystemConfig(Dict()),
        SolutionCandidate(1, [0 0 0], 0, Set())
    )
    sysconf, candidate = perceive(cohda, [init_wm])
    sysconf, candidate = decide(cohda, cohda.decider, sysconf, candidate)

    @test candidate.schedules[1, :] == [1, 1, 1]
    @test sysconf.schedule_choices[1].counter == 2
end

@testset "TestOnExchangeCohda" begin
    test_carrier = TestCarrier(test_neighbors=Set([1]))
    cohda_part_1 = create_cohda_participant(1, [[1, 1, 0.0], [1, 1, 1], [4, 2, 1], [0, 1, 0]])
    cohda_part_2 = create_cohda_participant(2, [[0.0, 1, 2], [1, 2.0, 3], [1, 1, 1], [4, 2, 3]])
    init_wm = create_cohda_start_message([1, 2.0, 1])

    on_exchange_message(cohda_part_1, test_carrier, init_wm, nothing)
    wm_to_send = test_carrier.test_neighbor_messages[1][end]

    @test wm_to_send.solution_candidate.schedules == [1 1 1]

    wm_to_send = on_exchange_message(cohda_part_2, test_carrier, wm_to_send, nothing)
    wm_to_send = test_carrier.test_neighbor_messages[1][end]
    wm_to_send = on_exchange_message(cohda_part_1, test_carrier, wm_to_send, nothing)
    wm_to_send = test_carrier.test_neighbor_messages[1][end]

    @test cohda_part_1.participant_id == 1
    @test cohda_part_1.memory.target_params == init_wm.target_params
    @test cohda_part_1.memory.system_config.schedule_choices ==
          Dict(2 => ScheduleSelection([0.0, 1.0, 2.0], 1), 1 => ScheduleSelection([1.0, 1.0, 0.0], 3))

    @test cohda_part_2.participant_id == 2
    @test cohda_part_2.memory.target_params == init_wm.target_params
    @test cohda_part_2.memory.system_config.schedule_choices ==
          Dict(2 => ScheduleSelection([0.0, 1.0, 2.0], 1), 1 => ScheduleSelection([1.0, 1.0, 1.0], 2))

    @test wm_to_send.solution_candidate.schedules == [1 1 0; 0 1 2]

    wm_to_send = on_exchange_message(cohda_part_2, test_carrier, wm_to_send, nothing)
    wm_to_send = test_carrier.test_neighbor_messages[1][end]

    @test !isnothing(wm_to_send)
    @test cohda_part_1.memory.solution_candidate.schedules == [1 1 0; 0 1 2]
    @test cohda_part_2.memory.solution_candidate.schedules == [1 1 0; 0 1 2]

    len_before = length(test_carrier.test_neighbor_messages[1])
    wm_to_send = on_exchange_message(cohda_part_1, test_carrier, wm_to_send, nothing)
    wm_to_send = test_carrier.test_neighbor_messages[1][end]

    @test len_before == length(test_carrier.test_neighbor_messages[1])
end

S_HINRICHS_CASE = [
    [
        [1.0, 1, 1, 1, 1],
        [4, 3, 3, 3, 3],
        [6, 6, 6, 6, 6],
        [9, 8, 8, 8, 8],
        [11, 11, 11, 11, 11],
    ],
    [
        [13, 12, 12, 12, 12],
        [15, 15, 15, 14, 14],
        [18, 17, 17, 17, 17],
        [20, 20, 20, 19, 19],
        [23, 22, 22, 22, 22],
    ],
    [
        [25, 24, 23, 23, 23],
        [27, 26, 26, 25, 25],
        [30, 29, 28, 28, 28],
        [32, 31, 31, 30, 30],
        [35, 34, 33, 33, 33],
    ],
    [
        [36, 35, 35, 34, 34],
        [39, 38, 37, 36, 36],
        [41, 40, 40, 39, 39],
        [44, 43, 42, 41, 41],
        [46, 45, 45, 44, 44],
    ],
    [
        [48, 47, 46, 45, 45],
        [50, 49, 48, 48, 47],
        [53, 52, 51, 50, 50],
        [55, 54, 53, 53, 52],
        [58, 57, 56, 55, 55],
    ],
    [
        [60, 58, 57, 56, 56],
        [62, 61, 60, 59, 58],
        [65, 63, 62, 61, 61],
        [67, 66, 65, 64, 63],
        [70, 68, 67, 66, 66],
    ],
    [
        [71, 70, 68, 67, 67],
        [74, 72, 71, 70, 69],
        [76, 75, 73, 72, 72],
        [79, 77, 76, 75, 74],
        [81, 80, 78, 77, 77],
    ],
    [
        [83, 81, 80, 78, 78],
        [85, 83, 82, 81, 80],
        [88, 86, 85, 83, 83],
        [90, 88, 87, 86, 85],
        [93, 91, 90, 88, 88],
    ],
    [
        [95, 92, 91, 90, 89],
        [97, 95, 93, 92, 91],
        [100, 97, 96, 95, 94],
        [102, 100, 98, 97, 96],
        [105, 102, 101, 100, 99],
    ],
    [
        [106, 104, 102, 101, 100],
        [109, 106, 105, 103, 102],
        [111, 109, 107, 106, 105],
        [114, 111, 110, 108, 107],
        [116, 114, 112, 111, 110],
    ],
]

@testset "TestOnExchangeCohdaHinrichs" begin
    test_carrier = TestCarrier(test_neighbors=Set([1]))
    cohda_parts = []
    for (i, schedule_set) in enumerate(S_HINRICHS_CASE)
        push!(cohda_parts, create_cohda_participant(i, schedule_set))
    end
    wm_to_send = create_cohda_start_message([542, 528, 519, 511, 509.0])
    last_length = -1
    while last_length == -1 || last_length < length(test_carrier.test_neighbor_messages[1])
        for cohda_part in cohda_parts
            last_length = last_length != -1 ? length(test_carrier.test_neighbor_messages[1]) : 0
            wm_to_send = on_exchange_message(cohda_part, test_carrier, wm_to_send, nothing)
            wm_to_send = test_carrier.test_neighbor_messages[1][end]
            if last_length == length(test_carrier.test_neighbor_messages[1])
                break
            end
        end
    end

    @test cohda_parts[1].memory.solution_candidate.perf == -5
    @test sum(cohda_parts[1].memory.solution_candidate.schedules, dims=1) == [543 529 520 512 510]
end