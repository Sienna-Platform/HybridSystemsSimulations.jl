@testset "Test HybridSystem Merchant-Only Simulation" begin
    # This test exercises a `Simulation` that contains ONLY the merchant
    # decision model (`MerchantHybridEnergyCase`). The merchant model receives
    # day-ahead and real-time prices as forecasts via CSV files (loaded into
    # the system `ext` dictionary), so no other decision/emulation model is
    # required to drive the simulation.

    horizon_merchant_rt = 24 * 12        # 288 5-min intervals = 24 hours
    horizon_merchant_da = 24             # 24 hourly intervals = 24 hours
    interval = Hour(24)

    sys_rts_merchant = PSB.build_RTS_GMLC_RT_sys(
        raw_data=PSB.RTS_DIR,
        horizon=horizon_merchant_rt,
        interval=interval,
    )

    # The merchant model needs a hybrid system to dispatch and a renewable
    # cost adjustment so that curtailment is meaningful. Reuse the existing
    # test utilities.
    modify_ren_curtailment_cost!(sys_rts_merchant)
    add_hybrid_to_chuhsi_bus!(sys_rts_merchant)

    sys = sys_rts_merchant
    sys.internal.ext = Dict{String, DataFrame}()
    dic = PSY.get_ext(sys)

    # Load the forecast prices from the test inputs. These cover three days
    # starting 2020-10-03, which is enough for a multi-step simulation.
    bus_name = "chuhsi"
    dic["λ_da_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_DA_prices.csv"), DataFrame)
    dic["λ_rt_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RT_prices.csv"), DataFrame)
    dic["horizon_RT"] = horizon_merchant_rt
    dic["horizon_DA"] = horizon_merchant_da

    hy_sys = first(get_components(HybridSystem, sys))
    PSY.set_ext!(hy_sys, deepcopy(dic))

    # Build the merchant decision model. Setting `ext["RT"] = true` forces
    # the decision model to use the renewable time series that ships with
    # the RTS-GMLC RT system (`RenewableDispatch__max_active_power`) which
    # is required when running inside a `Simulation`.
    decision_optimizer_DA = DecisionModel(
        MerchantHybridEnergyCase,
        ProblemTemplate(CopperPlatePowerModel),
        sys;
        optimizer=HiGHS_optimizer,
        calculate_conflict=true,
        store_variable_names=true,
        name="MerchantHybridEnergyCase_DA",
    )
    decision_optimizer_DA.ext["RT"] = true

    # Build a Simulation that contains ONLY the merchant decision model.
    models = SimulationModels(decision_models=[decision_optimizer_DA])

    sequence = SimulationSequence(
        models=models,
        ini_cond_chronology=InterProblemChronology(),
    )

    num_steps = 2
    start_time = DateTime("2020-10-03T00:00:00")

    sim = Simulation(
        name="merchant_only_sim",
        steps=num_steps,
        models=models,
        sequence=sequence,
        initial_time=start_time,
        simulation_folder=mktempdir(cleanup=true),
    )

    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim; enable_progress_bar=false)
    @test execute_out == PSI.RunStatus.SUCCESSFUL

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

    # And each result entry has the expected length according to the model
    # horizons.
    for (_, df) in da_bid_out
        @test size(df, 1) == horizon_merchant_da
    end
    for (_, df) in rt_bid_out
        @test size(df, 1) == horizon_merchant_rt
    end
end
