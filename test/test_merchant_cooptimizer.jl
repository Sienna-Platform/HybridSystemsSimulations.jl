function _run_cooptimizer_case(with_services::Bool)
    horizon_merchant_rt = 288
    horizon_merchant_da = 24
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
        attach_services = true,
        rt_steps = horizon_merchant_rt,
        da_steps = horizon_merchant_rt,
        injection_rt_steps = injection_steps,
        use_rt_resolution_for_da = true,
    )
    strip_non_hybrid_single_time_series!(sys)
    ts_rt = PSY.get_time_series(
        IS.SingleTimeSeries,
        hy_sys,
        "RenewableDispatch__max_active_power",
    )
    @test length(timestamp(IS.get_data(ts_rt))) >= horizon_merchant_rt

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
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridDispatchWithReserves))
    decision_optimizer_DA = DecisionModel(
        MerchantHybridCooptimizerCase,
        template,
        sys;
        optimizer = HiGHS_optimizer,
        calculate_conflict = true,
        optimizer_solve_log_print = false,
        store_variable_names = true,
        initial_time = DateTime("2020-10-03T00:00:00"),
        resolution = Minute(5),
        interval = Minute(5),
        horizon = Hour(24),
        name = "MerchantHybridCooptimizerCase_DA",
    )

    @test build!(decision_optimizer_DA; output_dir = mktempdir()) ==
          PSI.ModelBuildStatus.BUILT
    @test solve!(decision_optimizer_DA) == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    results = PSI.OptimizationProblemResults(decision_optimizer_DA)
    var_results = results.variable_values
    rt_bid_out = read_variable(results, "EnergyRTBidOut__HybridSystem")
    da_bid_out = var_results[PSI.VariableKey{HSS.EnergyDABidOut, HybridSystem}("")]
    # DA bid and reserve bid variables span hourly DA slots; RT bids span RT steps.
    @test length(da_bid_out[!, 1]) == horizon_merchant_da
    @test length(rt_bid_out[!, 1]) == 288
    if with_services
        regup_bid_out =
            var_results[PSI.VariableKey{
                HSS.BidReserveVariableOut,
                VariableReserve{ReserveUp},
            }(
                "Reg_Up",
            )]
        @test length(regup_bid_out[!, 1]) == horizon_merchant_da
    end
end

@testset "Test HybridSystem Merchant Decision Model Cooptimizer" begin
    _run_cooptimizer_case(true)
end

@testset "Test HybridSystem Merchant Decision Model Cooptimizer Minimal Services" begin
    _run_cooptimizer_case(false)
end
