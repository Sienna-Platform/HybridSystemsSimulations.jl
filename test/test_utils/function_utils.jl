using TimeSeries

function modify_ren_curtailment_cost!(sys)
    rdispatch = get_components(RenewableDispatch, sys)
    for ren in rdispatch
        # We consider 15 $/MWh as a reasonable cost for renewable curtailment
        cost = PSY.RenewableGenerationCost(nothing)
        set_operation_cost!(ren, cost)
    end
    return
end

function _build_battery(
    bus::PSY.Bus,
    energy_capacity,
    rating,
    efficiency_in,
    efficiency_out,
)
    name = string(bus.number) * "_BATTERY"
    device = PSY.EnergyReservoirStorage(;
        name = name,
        available = true,
        bus = bus,
        prime_mover_type = PSY.PrimeMovers.BA,
        storage_technology_type = PSY.StorageTech.OTHER_CHEM,
        storage_capacity = energy_capacity,
        storage_level_limits = (min = 0.05, max = 1.0),
        initial_storage_capacity_level = 0.5,
        rating = rating,
        active_power = rating,
        input_active_power_limits = (min = 0.0, max = rating),
        output_active_power_limits = (min = 0.0, max = rating),
        efficiency = (in = efficiency_in, out = efficiency_out),
        reactive_power = 0.0,
        reactive_power_limits = nothing,
        base_power = 100.0,
        operation_cost = PSY.StorageCost(nothing),
    )
    return device
end

function add_hybrid_to_chuhsi_bus!(sys::System; horizon_rt_steps::Union{Nothing, Int} = nothing)
    bus = get_component(Bus, sys, "Chuhsi")
    bat = _build_battery(bus, 4.0, 2.0, 0.93, 0.93)
    # Wind is taken from Bus 317: Chuhsi
    # Thermal and Load is taken from adjacent bus 318: Clark
    ren_name = "317_WIND_1"
    thermal_name = "318_CC_1"
    load_name = "Clark"
    renewable = get_component(StaticInjection, sys, ren_name)
    thermal = get_component(StaticInjection, sys, thermal_name)
    load = get_component(PowerLoad, sys, load_name)
    # Create the Hybrid
    hybrid_name = string(bus.number) * "_Hybrid"
    hybrid = PSY.HybridSystem(;
        name = hybrid_name,
        available = true,
        status = true,
        bus = bus,
        active_power = 1.0,
        reactive_power = 0.0,
        base_power = 100.0,
        operation_cost = PSY.MarketBidCost(nothing),
        thermal_unit = thermal, #new_th,
        electric_load = load, #new_load,
        storage = bat,
        renewable_unit = renewable, #new_ren,
        interconnection_impedance = 0.0 + 0.0im,
        interconnection_rating = nothing,
        input_active_power_limits = (min = 0.0, max = 10.0),
        output_active_power_limits = (min = 0.0, max = 10.0),
        reactive_power_limits = nothing,
    )
    # Add Hybrid (add_component! internally copies subcomponent time series to hybrid)
    add_component!(sys, hybrid)
    # Ensure DA-named time series exists so merchant decision models that request
    # "RenewableDispatch__max_active_power_da" (DA path) find metadata on the hybrid.
    _add_hybrid_renewable_da_time_series!(sys, hybrid; horizon_rt_steps = horizon_rt_steps)
    return
end

function _add_hybrid_renewable_da_time_series!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem;
    horizon_rt_steps::Union{Nothing, Int} = nothing,
)
    try
        ts = PSY.get_time_series(
            IS.SingleTimeSeries,
            hybrid,
            "RenewableDispatch__max_active_power",
        )
        single_da = IS.SingleTimeSeries(ts, "RenewableDispatch__max_active_power_da")
        PSY.add_time_series!(sys, hybrid, single_da)
    catch
        nothing
    end

    # Force deterministic windows to exactly match the merchant RT horizon request
    # when provided (instead of only "at least as long"), so simulation updates
    # don't request out-of-window ranges.
    try
        ts_det = PSY.get_time_series(
            IS.DeterministicSingleTimeSeries,
            hybrid,
            "RenewableDispatch__max_active_power",
        )
        resolution = IS.get_resolution(ts_det)
        interval = IS.get_interval(ts_det)
        current_horizon = IS.get_horizon(ts_det)

        target_horizon =
            isnothing(horizon_rt_steps) ? current_horizon : (horizon_rt_steps * resolution)

        PSY.transform_single_time_series!(
            sys,
            target_horizon,
            interval;
            resolution = resolution,
        )
    catch
        nothing
    end
    return
end