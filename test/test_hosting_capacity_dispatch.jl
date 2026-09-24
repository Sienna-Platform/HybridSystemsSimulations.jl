@testset "HybridHostingCapacityDispatch solve LOp > 0" begin
    sys_rts_da = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    modify_ren_curtailment_cost!(sys_rts_da)
    add_hybrid_to_chuhsi_bus!(sys_rts_da)
    hybrid = first(get_components(HybridSystem, sys_rts_da))
    # Device limits and l_op_ub are SYSTEM_BASE pu (base_power typically 100).
    l_op_ub_pu = Float64(PSY.get_output_active_power_limits(hybrid).max)
    base_mw = Float64(PSY.get_base_power(sys_rts_da))

    template_uc_dcp = get_uc_dcp_template()
    set_device_model!(
        template_uc_dcp,
        DeviceModel(
            PSY.HybridSystem,
            HybridHostingCapacityDispatch;
            attributes = Dict{String, Any}(
                "l_op_ub" => l_op_ub_pu,
                "cycling" => false,
                "regularization" => false,
                "reservation" => true,
                "energy_target" => false,
            ),
        ),
    )

    m = DecisionModel(
        template_uc_dcp,
        sys_rts_da;
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
    )

    build_out = PSI.build!(m; output_dir = mktempdir(; cleanup = true))
    @test build_out == PSI.ModelBuildStatus.BUILT
    solve_out = PSI.solve!(m)
    @test solve_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    res = PSI.OptimizationProblemResults(m)
    lop_df = PSI.read_variable(res, "LOpVariable__HybridSystem")
    @test :value in propertynames(lop_df)
    # convert_result_to_natural_units(::Type{LOpVariable}) → MW
    lop_mw = Float64(first(lop_df[!, :value]))
    @test lop_mw > 0.0
    @test lop_mw != 1.0 || l_op_ub_pu * base_mw ≈ 1.0
    @test lop_mw <= l_op_ub_pu * base_mw + 1e-6
end

@testset "HybridHostingCapacityDispatch load-only solve LOp > 0" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    # Match HostingCapacity production: -L_op only wins when injection costs are zero.
    modify_ren_curtailment_cost!(sys)
    for g in get_components(ThermalGen, sys)
        set_operation_cost!(g, PSY.ThermalGenerationCost(nothing))
    end
    for g in get_components(HydroGen, sys)
        set_operation_cost!(g, PSY.HydroGenerationCost(nothing))
    end
    bus = get_component(Bus, sys, "Chuhsi")
    base_mw = Float64(PSY.get_base_power(sys))
    l_op_ub_mw = 50.0
    l_op_ub_pu = l_op_ub_mw / base_mw
    load = PowerLoad(;
        name = "hosting_load_only",
        available = true,
        bus = bus,
        active_power = 1.0,
        reactive_power = 0.0,
        base_power = base_mw,
        max_active_power = 1.0,
        max_reactive_power = 0.0,
    )
    hybrid = PSY.HybridSystem(;
        name = "Chuhsi_HostingLoadOnly",
        available = true,
        status = true,
        bus = bus,
        active_power = 0.0,
        reactive_power = 0.0,
        base_power = base_mw,
        operation_cost = PSY.MarketBidCost(nothing),
        thermal_unit = nothing,
        electric_load = load,
        storage = nothing,
        renewable_unit = nothing,
        interconnection_impedance = 0.0 + 0.0im,
        interconnection_rating = l_op_ub_pu,
        input_active_power_limits = (min = 0.0, max = l_op_ub_pu),
        output_active_power_limits = (min = 0.0, max = l_op_ub_pu),
        reactive_power_limits = nothing,
    )
    add_component!(sys, hybrid)

    existing = first(get_components(PowerLoad, sys))
    ts = get_time_series(SingleTimeSeries, existing, "max_active_power")
    data = IS.get_data(ts)
    timestamps = collect(getfield(data, :timestamp))
    n = min(48, length(timestamps))
    ones_ta = TimeSeries.TimeArray(timestamps[1:n], ones(n))
    PSY.add_time_series!(
        sys,
        hybrid,
        PSY.SingleTimeSeries("PowerLoad__max_active_power", ones_ta),
    )

    template_uc_dcp = get_uc_dcp_template()
    set_device_model!(
        template_uc_dcp,
        DeviceModel(
            PSY.HybridSystem,
            HybridHostingCapacityDispatch;
            attributes = Dict{String, Any}(
                "l_op_ub" => l_op_ub_pu,
                "cycling" => false,
                "regularization" => false,
                "reservation" => true,
                "energy_target" => false,
            ),
        ),
    )

    m = DecisionModel(
        template_uc_dcp,
        sys;
        optimizer = HiGHS_optimizer,
        store_variable_names = true,
    )
    build_out = PSI.build!(m; output_dir = mktempdir(; cleanup = true))
    @test build_out == PSI.ModelBuildStatus.BUILT
    solve_out = PSI.solve!(m)
    @test solve_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

    res = PSI.OptimizationProblemResults(m)
    lop_df = PSI.read_variable(res, "LOpVariable__HybridSystem")
    @test :value in propertynames(lop_df)
    lop_mw = Float64(first(lop_df[!, :value]))
    @test lop_mw > 0.0
    @test lop_mw != 1.0
    @test lop_mw <= l_op_ub_mw + 1e-6
end
