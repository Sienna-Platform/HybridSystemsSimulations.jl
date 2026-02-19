@testset "Test HybridSystem Optimizer DecisionModel Sequence" begin
    ###############################
    ######## Load Systems #########
    ###############################

    sys_rts_da = PSB.build_RTS_GMLC_DA_sys(; raw_data = PSB.RTS_DIR, horizon = 48)
    sys_rts_rt =
        PSB.build_RTS_GMLC_RT_sys(;
            raw_data = PSB.RTS_DIR,
            horizon = 864,
            interval = Minute(1440),
        )

    # There is no Wind + Thermal in a Single Bus.
    # We will try to pick the Wind in 317 bus Chuhsi
    # It does not have thermal and load, so we will pick the adjacent bus 318: Clark

    systems = [sys_rts_da, sys_rts_rt]
    for sys in systems
        bus_to_add = "Chuhsi" # "Barton"
        modify_ren_curtailment_cost!(sys)
        add_battery_to_bus!(sys, bus_to_add)
    end

    ###############################
    ###### Create Templates #######
    ###############################

    template_uc_dcp = get_uc_dcp_template()

    ###############################
    ###### Simulation Params ######
    ###############################

    mipgap = 0.01
    num_steps = 3
    starttime = DateTime("2020-10-03T00:00:00")

    # Attach Data to System Ext
    bus_name = "chuhsi"

    sys_rts_rt.internal.ext = Dict{String, DataFrame}()
    dic = get_ext(sys_rts_rt)
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
        MerchantHybridEnergyOnly,
        ProblemTemplate(CopperPlatePowerModel),
        sys_rts_rt;
        optimizer = HiGHS_optimizer,
        horizon = 864,
    )

    sim_optimizer = build_simulation_case_optimizer(
        template_uc_dcp,
        m,
        sys_rts_da,
        sys_rts_rt,
        num_steps,
        0.01,
        starttime,
    )

    build_out = build!(sim_optimizer)
    @test build_out == PSI.BuildStatus.BUILT

    # Fix Issue src and dest arrays
    #@test execute!(sim_optimizer; enable_progress_bar=true) == PSI.RunStatus.SUCCESSFUL
end
