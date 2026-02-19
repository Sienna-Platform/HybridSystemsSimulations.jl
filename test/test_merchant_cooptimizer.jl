@testset "Test HybridSystem Merchant Decision Model Cooptimizer" begin
    #### Create Systems ####
    horizon_merchant_rt = 288
    horizon_merchant_da = 24
    sys_rts_merchant = PSB.build_RTS_GMLC_RT_sys(;
        raw_data = PSB.RTS_DIR,
        horizon = horizon_merchant_rt,
        interval = Hour(24),
    )
    sys_rts_da = PSB.build_RTS_GMLC_DA_sys(; raw_data = PSB.RTS_DIR, horizon = 24)

    # There is no Wind + Thermal in a Single Bus.
    # We will try to pick the Wind in 317 bus Chuhsi
    # It does not have thermal and load, so we will pick the adjacent bus 318: Clark
    for s in [sys_rts_da, sys_rts_merchant]
        bus_to_add = "Chuhsi" # "Barton"
        modify_ren_curtailment_cost!(s)
        add_hybrid_to_chuhsi_bus!(s)
    end

    sys = sys_rts_merchant
    sys.internal.ext = Dict{String, DataFrame}()
    dic = PSY.get_ext(sys)

    # Add prices to ext. Only three days.
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
    services = get_components(VariableReserve, sys)
    for service in services
        serv_name = get_name(service)
        if contains(serv_name, "Spin_Up_R1") |
           contains(serv_name, "Spin_Up_R2") |
           contains(serv_name, "Flex")
            continue
        else
            add_service!(hy_sys, service, sys)
        end
    end
    PSY.set_ext!(hy_sys, deepcopy(dic))

    # Set decision model for Optimizer
    decision_optimizer_DA = DecisionModel(
        MerchantHybridCooptimizerCase,
        ProblemTemplate(CopperPlatePowerModel),
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

    results = ProblemResults(decision_optimizer_DA)
    var_results = results.variable_values
    rt_bid_out = read_variable(results, "EnergyRTBidOut__HybridSystem")
    da_bid_out = var_results[PSI.VariableKey{HSS.EnergyDABidOut, HybridSystem}("")]
    regup_bid_out =
        var_results[PSI.VariableKey{HSS.BidReserveVariableOut, VariableReserve{ReserveUp}}(
            "Reg_Up",
        )]
    @test length(da_bid_out[!, 1]) == 24
    @test length(rt_bid_out[!, 1]) == 288
    @test length(regup_bid_out[!, 1]) == 24
end
