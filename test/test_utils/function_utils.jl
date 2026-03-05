using TimeSeries

function get_da_max_active_power_series(r_gen, starttime, steps::Int)
    ta = get_time_series_array(
        SingleTimeSeries,
        r_gen,
        "max_active_power";
        start_time = starttime,
        len = 24 * steps,
    )
    return DataFrame(; DateTime = timestamp(ta), MaxPower = values(ta))
end

function get_rt_max_active_power_series(r_gen, starttime, steps::Int)
    ta = get_time_series_array(
        SingleTimeSeries,
        r_gen,
        "max_active_power";
        start_time = starttime,
        len = 24 * 12 * steps,
    )
    return DataFrame(; DateTime = timestamp(ta), MaxPower = values(ta))
end

function get_battery_params(b_gen::PSY.EnergyReservoirStorage)
    battery_params_names = [
        "initial_energy",
        "SoC_min",
        "SoC_max",
        "P_ch_min",
        "P_ch_max",
        "P_ds_min",
        "P_ds_max",
        "η_in",
        "η_out",
    ]
    SoC_min, SoC_max = get_state_of_charge_limits(b_gen)
    P_ch_min, P_ch_max = get_input_active_power_limits(b_gen)
    P_ds_min, P_ds_max = get_output_active_power_limits(b_gen)
    η_in, η_out = get_efficiency(b_gen)
    battery_params_vals = [
        get_initial_energy(b_gen),
        SoC_min,
        SoC_max,
        P_ch_min,
        P_ch_max,
        P_ds_min,
        P_ds_max,
        η_in,
        η_out,
    ]
    return DataFrame(; ParamName = battery_params_names, Value = battery_params_vals)
end

function get_thermal_params(t_gen)
    P_min, P_max = get_active_power_limits(t_gen)
    # TODO Implement the proper three part cost
    three_cost = get_operation_cost(t_gen)
    first_part = three_cost.variable[1]
    second_part = three_cost.variable[2]
    slope = (second_part[1] - first_part[1]) / (second_part[2] - first_part[2]) # $/MWh
    fix_cost = three_cost.fixed # $/h
    return DataFrame(;
        ParamName = ["P_min", "P_max", "C_var", "C_fix"],
        Value = [P_min, P_max, slope, fix_cost],
    )
end

function get_row_val(df, row_name)
    return df[only(findall(==(row_name), df.ParamName)), :]["Value"]
end

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

function add_battery_to_bus!(sys::System, bus_name::String)
    bus = get_component(Bus, sys, bus_name)
    bat = _build_battery(bus, 4.0, 2.0, 0.93, 0.93)
    add_component!(sys, bat)
    return
end

function add_hybrid_to_chuhsi_bus!(sys::System)
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
    _add_hybrid_renewable_da_time_series!(sys, hybrid)
    return
end

function _add_hybrid_renewable_da_time_series!(sys::PSY.System, hybrid::PSY.HybridSystem)
    try
        ts = PSY.get_time_series(IS.SingleTimeSeries, hybrid, "RenewableDispatch__max_active_power")
        single_da = IS.SingleTimeSeries(ts, "RenewableDispatch__max_active_power_da")
        PSY.add_time_series!(sys, hybrid, single_da)
    catch
        nothing
    end

    # Use a horizon long enough to cover the
    # decision model window (e.g. 48 steps at 5-min = 4 hours); otherwise get_window
    # fails in smoke testswith "timestamp not within" when the model requests 4 hours of data.
    try
        ts_det = PSY.get_time_series(
            IS.DeterministicSingleTimeSeries,
            hybrid,
            "RenewableDispatch__max_active_power",
        )
        horizon = IS.get_horizon(ts_det)
        interval = IS.get_interval(ts_det)
        resolution = IS.get_resolution(ts_det)
        if resolution == Dates.Minute(5) && horizon < Dates.Hour(4)
            horizon = Dates.Hour(4)
        end
        PSY.transform_single_time_series!(sys, horizon, interval; resolution = resolution)
    catch
        nothing
    end
    return
end
