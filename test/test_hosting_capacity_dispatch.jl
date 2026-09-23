@testset "HybridHostingCapacityDispatch solve LOp > 0" begin
    sys_rts_da = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    modify_ren_curtailment_cost!(sys_rts_da)
    add_hybrid_to_chuhsi_bus!(sys_rts_da)
    hybrid = first(get_components(HybridSystem, sys_rts_da))
    l_op_ub = PSY.get_output_active_power_limits(hybrid).max

    template_uc_dcp = get_uc_dcp_template()
    set_device_model!(
        template_uc_dcp,
        DeviceModel(
            PSY.HybridSystem,
            HybridHostingCapacityDispatch;
            attributes = Dict{String, Any}(
                "l_op_ub" => Float64(l_op_ub),
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
    lop_val = nothing
    for name in names(lop_df)
        v = first(lop_df[!, name])
        if v isa Number
            lop_val = Float64(v)
            break
        end
    end
    @test lop_val !== nothing
    @test lop_val > 0.0
end

@testset "HybridHostingCapacityDispatch load-only solve LOp > 0" begin
    sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
    bus = get_component(Bus, sys, "Chuhsi")
    load = PowerLoad(;
        name = "hosting_load_only",
        available = true,
        bus = bus,
        active_power = 1.0,
        reactive_power = 0.0,
        base_power = 100.0,
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
        base_power = 100.0,
        operation_cost = PSY.MarketBidCost(nothing),
        thermal_unit = nothing,
        electric_load = load,
        storage = nothing,
        renewable_unit = nothing,
        interconnection_impedance = 0.0 + 0.0im,
        interconnection_rating = 50.0,
        input_active_power_limits = (min = 0.0, max = 50.0),
        output_active_power_limits = (min = 0.0, max = 50.0),
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
                "l_op_ub" => 50.0,
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
    lop_val = nothing
    for name in names(lop_df)
        v = first(lop_df[!, name])
        if v isa Number
            lop_val = Float64(v)
            break
        end
    end
    @test lop_val !== nothing
    @test lop_val > 0.0
end
