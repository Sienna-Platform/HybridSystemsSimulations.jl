@testset "Test HybridSystem Merchant Optimizer Sequence Build" begin
    sys_rts_da = PSB.build_RTS_GMLC_DA_sys(; raw_data = PSB.RTS_DIR, horizon = 24)
    sys_rts_rt = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = 288,
        interval = Hour(24),
    )

    modify_ren_curtailment_cost!(sys_rts_rt)
    add_hybrid_to_chuhsi_bus!(sys_rts_rt; horizon_rt_steps = 288)

    bus_name = "chuhsi"
    sys_rts_rt.internal.ext = Dict{String, DataFrame}()
    dic = get_ext(sys_rts_rt)
    dic["λ_da_df"] = CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_DA_prices.csv"), DataFrame)
    dic["λ_rt_df"] = CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RT_prices.csv"), DataFrame)
    dic["horizon_RT"] = 288
    dic["horizon_DA"] = 24

    hy_sys = first(get_components(HybridSystem, sys_rts_rt))
    PSY.set_ext!(hy_sys, deepcopy(dic))

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
        name = "MerchantHybridEnergyCase_Sequence",
    )

    sim_optimizer = build_simulation_case_optimizer(
        get_uc_dcp_template(),
        decision_optimizer,
        sys_rts_da,
        sys_rts_rt,
        2,
        0.01,
        DateTime("2020-10-03T00:00:00"),
    )

    @test build!(sim_optimizer) == PSI.SimulationBuildStatus.BUILT
    @test execute!(sim_optimizer; enable_progress_bar = false) ==
                 PSI.RunStatus.SUCCESSFULLY_FINALIZED
end
