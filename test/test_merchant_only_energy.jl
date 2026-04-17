function _run_only_energy_case(horizon_merchant_rt::Int, horizon_merchant_da::Int)
    sys = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = horizon_merchant_rt,
        interval = Hour(24),
    )
    modify_ren_curtailment_cost!(sys)
    add_hybrid_to_chuhsi_bus!(sys; horizon_rt_steps = horizon_merchant_rt)

    sys.internal.ext = Dict{String, DataFrame}()
    dic = PSY.get_ext(sys)
    bus_name = "chuhsi"
    dic["λ_da_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_DA_prices.csv"), DataFrame)
    dic["λ_rt_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RT_prices.csv"), DataFrame)
    dic["horizon_RT"] = horizon_merchant_rt
    dic["horizon_DA"] = horizon_merchant_da

    hy_sys = first(get_components(HybridSystem, sys))
    PSY.set_ext!(hy_sys, deepcopy(dic))
    ts_da = PSY.get_time_series(
        IS.SingleTimeSeries,
        hy_sys,
        "RenewableDispatch__max_active_power_da",
    )
    ts_rt =
        PSY.get_time_series(
            IS.DeterministicSingleTimeSeries,
            hy_sys,
            "RenewableDispatch__max_active_power",
        )
    @test !isnothing(ts_da)
    @test IS.get_horizon(ts_rt) >= horizon_merchant_rt * IS.get_resolution(ts_rt)

    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridEnergyOnlyDispatch))
    decision_optimizer_DA = DecisionModel(
        MerchantHybridEnergyCase,
        template,
        sys;
        optimizer = HiGHS_optimizer,
        calculate_conflict = true,
        store_variable_names = true,
        initial_time = DateTime("2020-10-03T00:00:00"),
        name = "MerchantHybridEnergyCase_DA",
    )

    build!(decision_optimizer_DA; output_dir = mktempdir())
    solve!(decision_optimizer_DA)

    results = PSI.OptimizationProblemResults(decision_optimizer_DA)
    var_results = results.variable_values
    rt_bid_out = read_variable(results, "EnergyRTBidOut__HybridSystem")
    da_bid_out = var_results[PSI.VariableKey{HSS.EnergyDABidOut, HybridSystem}("")]
    @test length(da_bid_out[!, 1]) == horizon_merchant_da
    @test length(rt_bid_out[!, 1]) == horizon_merchant_rt
end

@testset "Test HybridSystem Merchant Decision Model Only Energy" begin
    _run_only_energy_case(288, 24)
end

@testset "Test HybridSystem Merchant Decision Model Only Energy Extended Horizon" begin
    _run_only_energy_case(864, 72)
end
