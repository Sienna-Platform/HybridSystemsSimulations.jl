@testset "Test HybridSystem Merchant-Only Simulation" begin
    # This test exercises a `Simulation` that contains ONLY the merchant
    # decision model (`MerchantHybridEnergyCase`). The merchant model is driven
    # by day-ahead and real-time market prices attached to the hybrid as time
    # series, so no other decision/emulation model is required.

    sys_rts_merchant = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = 24,
        interval = Hour(1),
    )

    # The merchant model needs a hybrid system to dispatch and a renewable cost
    # adjustment so that curtailment is meaningful. Reuse the existing test
    # utilities and attach the market price time series.
    modify_ren_curtailment_cost!(sys_rts_merchant)
    add_hybrid_to_chuhsi_bus!(sys_rts_merchant; horizon_rt_steps = 288)
    hy_sys = first(get_components(HybridSystem, sys_rts_merchant))
    attach_hybrid_market_time_series!(
        sys_rts_merchant,
        hy_sys;
        bus_name = "chuhsi",
        rt_steps = 288,
        da_steps = 288,
        injection_rt_steps = max(288, 300),
        use_rt_resolution_for_da = true,
    )
    strip_non_hybrid_single_time_series!(sys_rts_merchant)

    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridEnergyOnlyDispatch))
    decision_optimizer_DA = DecisionModel(
        MerchantHybridEnergyCase,
        template,
        sys_rts_merchant;
        optimizer = HiGHS_optimizer,
        calculate_conflict = true,
        store_variable_names = true,
        initial_time = DateTime("2020-10-03T00:00:00"),
        horizon = Hour(24),
        resolution = Minute(5),
        interval = Hour(1),
        name = "MerchantHybridEnergyCase_DA",
    )

    # Build a Simulation that contains ONLY the merchant decision model.
    models = SimulationModels(; decision_models = [decision_optimizer_DA])

    sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
    )

    # The hybrid merchant fixtures leave a single forecast window that satisfies
    # PowerSimulations `_check_steps` for this RT system.
    num_steps = 1
    start_time = DateTime("2020-10-03T00:00:00")

    sim = Simulation(;
        name = "merchant_only_sim",
        steps = num_steps,
        models = models,
        sequence = sequence,
        initial_time = start_time,
        simulation_folder = mktempdir(; cleanup = true),
    )

    @test build!(sim) == PSI.SimulationBuildStatus.BUILT
    @test execute!(sim; enable_progress_bar = false) ==
          PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = SimulationResults(sim)
    result_opt = get_decision_problem_results(results, "MerchantHybridEnergyCase_DA")

    da_bid_out = read_variable(result_opt, "EnergyDABidOut__HybridSystem")
    da_bid_in = read_variable(result_opt, "EnergyDABidIn__HybridSystem")
    rt_bid_out = read_variable(result_opt, "EnergyRTBidOut__HybridSystem")
    rt_bid_in = read_variable(result_opt, "EnergyRTBidIn__HybridSystem")

    # One result entry per simulation step.
    @test length(da_bid_out) == num_steps
    @test length(da_bid_in) == num_steps
    @test length(rt_bid_out) == num_steps
    @test length(rt_bid_in) == num_steps

    # DA bids are hourly (24 slots); RT bids are 5-min (288 slots).
    for (_, df) in da_bid_out
        @test size(df, 1) == 24
    end
    for (_, df) in rt_bid_out
        @test size(df, 1) == 288
    end
end
