@testset "Test HybridSystem CoOptimizer DecisionModel" begin
    sys = PSB.build_RTS_GMLC_RT_sys(; raw_data = PSB.RTS_DIR, horizon = 864)

    # Attach Data to System Ext
    bus_name = "chuhsi"

    sys.internal.ext = Dict{String, DataFrame}()
    dic = get_ext(sys)
    dic["b_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_battery_data.csv"), DataFrame)
    dic["th_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_thermal_data.csv"), DataFrame)
    dic["P_da"] = CSV.read(
        joinpath(TEST_DIR, "inputs/$(bus_name)_renewable_forecast_DA.csv"),
        DataFrame,
    )
    dic["P_rt"] = CSV.read(
        joinpath(TEST_DIR, "inputs/$(bus_name)_renewable_forecast_RT.csv"),
        DataFrame,
    )
    dic["λ_da_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_DA_AS_prices.csv"), DataFrame)
    dic["λ_rt_df"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_RT_prices.csv"), DataFrame)
    dic["Pload_da"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_load_forecast_DA.csv"), DataFrame)
    dic["Pload_rt"] =
        CSV.read(joinpath(TEST_DIR, "inputs/$(bus_name)_load_forecast_RT.csv"), DataFrame)

    ### Create Decision Problem
    m = DecisionModel(
        MerchantHybridCooptimized,
        ProblemTemplate(CopperPlatePowerModel),
        sys;
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
    )
    build_out = PSI.build!(m; output_dir = mktempdir(; cleanup = true))
    @test build_out == PSI.BuildStatus.BUILT
    solve_out = PSI.solve!(m)
    @test solve_out == PSI.RunStatus.SUCCESSFUL
    res = ProblemResults(m)
    dic_res = get_variable_values(res)

    energy_rt_out = read_variable(res, "EnergyRTBidOut__HybridSystem")[!, 2]
    da_bid_out = dic_res[PSI.VariableKey{EnergyDABidOut, HybridSystem}("")][!, 1]

    @test length(energy_rt_out) == 864
    @test length(da_bid_out) == 72
end
