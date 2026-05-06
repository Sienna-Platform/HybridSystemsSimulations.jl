@testset "Test HybridSystem Merchant Optimizer Sequence Build" begin
    # Fast dev loop: skip `execute!` (UC + merchant solves dominate runtime).
    #   HSS_MERCHANT_SEQUENCE_FAST=1 julia --project=. -e 'using Pkg; Pkg.test(; test_args=["test_merchant_sequence"])'
    merchant_seq_fast_env =
        lowercase(get(ENV, "HSS_MERCHANT_SEQUENCE_FAST", "0")) in ("1", "true", "yes")

    sys_rts_da = PSB.build_RTS_GMLC_DA_sys(; raw_data = PSB.RTS_DIR, horizon = 24)
    # Forecast horizon (hours) must match `DecisionModel` so device DST and the model agree.
    sys_rts_rt = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = 24,
        interval = Hour(1),
    )

    modify_ren_curtailment_cost!(sys_rts_rt)
    add_hybrid_to_chuhsi_bus!(sys_rts_rt; horizon_rt_steps = 288)
    hy_sys = first(get_components(HybridSystem, sys_rts_rt))
    attach_hybrid_market_time_series!(
        sys_rts_rt,
        hy_sys;
        bus_name = "chuhsi",
        rt_steps = 288,
        da_steps = 288,
        injection_rt_steps = max(288, 300),
        use_rt_resolution_for_da = true,
    )
    strip_non_hybrid_single_time_series!(sys_rts_rt)

    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridEnergyOnlyDispatch))
    decision_optimizer = DecisionModel(
        MerchantHybridEnergyCase,
        template,
        sys_rts_rt;
        optimizer = HiGHS_optimizer,
        calculate_conflict = true,
        store_variable_names = true,
        initial_time = DateTime("2020-10-03T00:00:00"),
        horizon = Hour(24),
        resolution = Minute(5),
        interval = Hour(1),
        name = "MerchantHybridEnergyCase_Sequence",
    )

    # One simulation step: hybrid merchant fixtures leave a single forecast window that satisfies
    # PowerSimulations `_check_steps` for this RT system (multi-step runs need longer horizons).
    sim_optimizer = build_simulation_case_optimizer(
        get_uc_dcp_template(),
        decision_optimizer,
        sys_rts_da,
        sys_rts_rt,
        1,
        0.01,
        DateTime("2020-10-03T00:00:00"),
    )

    @test build!(sim_optimizer) == PSI.SimulationBuildStatus.BUILT
    if merchant_seq_fast_env
        @info "HSS_MERCHANT_SEQUENCE_FAST: skipping execute! — unset env for full simulation run."
    else
        @test execute!(sim_optimizer; enable_progress_bar = false) ==
              PSI.RunStatus.SUCCESSFULLY_FINALIZED
    end
end
