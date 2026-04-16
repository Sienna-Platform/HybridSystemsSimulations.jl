function _run_cooptimizer_case(with_services::Bool)
    horizon_merchant_rt = 288
    horizon_merchant_da = 24
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
    dic["λ_Reg_Up"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RegUp_prices.csv"), DataFrame)
    dic["λ_Reg_Down"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RegDown_prices.csv"), DataFrame)
    dic["λ_Spin_Up_R3"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_Spin_prices.csv"), DataFrame)
    dic["horizon_RT"] = horizon_merchant_rt
    dic["horizon_DA"] = horizon_merchant_da

    hy_sys = first(get_components(HybridSystem, sys))
    ts_rt =
        PSY.get_time_series(IS.DeterministicSingleTimeSeries, hy_sys, "RenewableDispatch__max_active_power")
    @test IS.get_horizon(ts_rt) >= horizon_merchant_rt * IS.get_resolution(ts_rt)

    if with_services
        services = get_components(VariableReserve, sys)
        for service in services
            serv_name = get_name(service)
            if contains(serv_name, "Spin_Up_R1") ||
               contains(serv_name, "Spin_Up_R2") ||
               contains(serv_name, "Flex")
                continue
            else
                add_service!(hy_sys, service, sys)
            end
        end
    end
    PSY.set_ext!(hy_sys, deepcopy(dic))

    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridDispatchWithReserves))
    decision_optimizer_DA = DecisionModel(
        MerchantHybridCooptimizerCase,
        template,
        sys;
        optimizer = HiGHS_optimizer,
        calculate_conflict = true,
        optimizer_solve_log_print = true,
        store_variable_names = true,
        initial_time = DateTime("2020-10-03T00:00:00"),
        name = "MerchantHybridCooptimizerCase_DA",
    )

    build!(decision_optimizer_DA; output_dir = mktempdir())
    solve!(decision_optimizer_DA)

    results = PSI.OptimizationProblemResults(decision_optimizer_DA)
    var_results = results.variable_values
    rt_bid_out = read_variable(results, "EnergyRTBidOut__HybridSystem")
    da_bid_out = var_results[PSI.VariableKey{HSS.EnergyDABidOut, HybridSystem}("")]
    @test length(da_bid_out[!, 1]) == 24
    @test length(rt_bid_out[!, 1]) == 288
    if with_services
        regup_bid_out =
            var_results[PSI.VariableKey{HSS.BidReserveVariableOut, VariableReserve{ReserveUp}}(
                "Reg_Up",
            )]
        @test length(regup_bid_out[!, 1]) == 24
    end
end

@testset "Test HybridSystem Merchant Decision Model Cooptimizer" begin
    _run_cooptimizer_case(true)
end

@testset "Test HybridSystem Merchant Decision Model Cooptimizer Minimal Services" begin
    _run_cooptimizer_case(false)
end
