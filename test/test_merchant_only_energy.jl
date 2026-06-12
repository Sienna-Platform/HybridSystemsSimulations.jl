function _run_only_energy_case(
    horizon_merchant_rt::Int,
    horizon_merchant_da::Int;
    use_rt_resolution_for_da::Bool = true,
)
    injection_steps = max(horizon_merchant_rt, 300)
    sys = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = horizon_merchant_da,
        interval = Hour(1),
    )
    modify_ren_curtailment_cost!(sys)
    add_hybrid_to_chuhsi_bus!(sys; horizon_rt_steps = horizon_merchant_rt)

    hy_sys = first(get_components(HybridSystem, sys))
    attach_hybrid_market_time_series!(
        sys,
        hy_sys;
        bus_name = "chuhsi",
        attach_services = false,
        rt_steps = horizon_merchant_rt,
        da_steps = use_rt_resolution_for_da ? horizon_merchant_rt : horizon_merchant_da,
        injection_rt_steps = injection_steps,
        use_rt_resolution_for_da = use_rt_resolution_for_da,
    )
    strip_non_hybrid_single_time_series!(sys)
    ts_rt = PSY.get_time_series(
        IS.SingleTimeSeries,
        hy_sys,
        "RenewableDispatch__max_active_power",
    )
    @test !isnothing(ts_rt)
    @test length(timestamp(IS.get_data(ts_rt))) >= horizon_merchant_rt

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
        resolution = Minute(5),
        interval = Minute(5),
        horizon = Hour(horizon_merchant_da),
        name = "MerchantHybridEnergyCase_DA",
    )

    @test build!(decision_optimizer_DA; output_dir = mktempdir()) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(decision_optimizer_DA) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = PSI.OptimizationProblemResults(decision_optimizer_DA)
    var_results = results.variable_values
    rt_bid_out = read_variable(results, "EnergyRTBidOut__HybridSystem")
    da_bid_out = var_results[PSI.VariableKey{HSS.EnergyDABidOut, HybridSystem}("")]
    # DA bid variables span hourly DA slots over the model horizon; RT bids span RT steps.
    @test length(da_bid_out[!, 1]) == horizon_merchant_da
    @test length(rt_bid_out[!, 1]) == horizon_merchant_rt
end

@testset "Test HybridSystem Merchant Decision Model Only Energy" begin
    _run_only_energy_case(288, 24)
end

@testset "Test HybridSystem Merchant Decision Model Only Energy Hourly DA Prices" begin
    _run_only_energy_case(288, 24; use_rt_resolution_for_da = false)
end

@testset "Test HybridSystem Merchant Decision Model Only Energy Extended Horizon" begin
    _run_only_energy_case(864, 72)
end
