@testset "Test HybridSystem OnlyEnergy DeviceModel" begin
    ###############################
    ######## Load Systems #########
    ###############################

    sys_rts_da = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

    # There is no Wind + Thermal in a Single Bus.
    # We will try to pick the Wind in 317 bus Chuhsi
    # It does not have thermal and load, so we will pick the adjacent bus 318: Clark
    bus_to_add = "Chuhsi" # "Barton"
    modify_ren_curtailment_cost!(sys_rts_da)
    add_hybrid_to_chuhsi_bus!(sys_rts_da)

    template_uc_dcp = get_uc_dcp_template()
    set_device_model!(
        template_uc_dcp,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => true),
        ),
    )

    m = DecisionModel(
        template_uc_dcp,
        sys_rts_da;
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
    )

    build_out = PSI.build!(m; output_dir = mktempdir(; cleanup = true))
    @test build_out == PSI.BuildStatus.BUILT
    solve_out = PSI.solve!(m)
    @test solve_out == PSI.RunStatus.SUCCESSFUL

    res = ProblemResults(m)
    dic_res = get_variable_values(res)

    p_out = read_variable(res, "ActivePowerOutVariable__HybridSystem")[!, 2]
    p_in = read_variable(res, "ActivePowerInVariable__HybridSystem")[!, 2]

    @test length(p_out) == 48
    @test length(p_in) == 48
end

@testset "Test HybridSystem DispatchWithReserves DeviceModel" begin
    ###############################
    ######## Load Systems #########
    ###############################

    sys_rts_da = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")

    # There is no Wind + Thermal in a Single Bus.
    # We will try to pick the Wind in 317 bus Chuhsi
    # It does not have thermal and load, so we will pick the adjacent bus 318: Clark
    bus_to_add = "Chuhsi" # "Barton"
    modify_ren_curtailment_cost!(sys_rts_da)
    add_hybrid_to_chuhsi_bus!(sys_rts_da)
    hybrid = first(get_components(HybridSystem, sys_rts_da))
    services = get_components(VariableReserve, sys_rts_da)
    for service in services
        serv_name = get_name(service)
        if contains(serv_name, "Spin_Up_R1") || contains(serv_name, "Spin_Up_R2")
            continue
        else
            add_service!(hybrid, service, sys_rts_da)
        end
    end

    template_uc_dcp = get_uc_dcp_template()
    set_device_model!(
        template_uc_dcp,
        DeviceModel(
            PSY.HybridSystem,
            HybridDispatchWithReserves;
            attributes = Dict{String, Any}("cycling" => true),
        ),
    )

    m = DecisionModel(
        template_uc_dcp,
        sys_rts_da;
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
    )

    build_out = PSI.build!(m; output_dir = mktempdir(; cleanup = true))
    @test build_out == PSI.BuildStatus.BUILT
    solve_out = PSI.solve!(m)
    @test solve_out == PSI.RunStatus.SUCCESSFUL

    res = ProblemResults(m)
    dic_res = get_variable_values(res)

    p_out = read_variable(res, "ActivePowerOutVariable__HybridSystem")[!, 2]
    p_in = read_variable(res, "ActivePowerInVariable__HybridSystem")[!, 2]

    @test length(p_out) == 48
    @test length(p_in) == 48
end
