using TimeSeries

function modify_ren_curtailment_cost!(sys)
    rdispatch = get_components(RenewableDispatch, sys)
    for ren in rdispatch
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

function add_hybrid_to_chuhsi_bus!(
    sys::System;
    horizon_rt_steps::Union{Nothing, Int} = nothing,
)
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
    return
end

function _build_scalar_time_series_from_csv(
    path::String,
    bus_name::String,
    ts_name::String;
    max_rows::Union{Nothing, Int} = nothing,
)
    df = CSV.read(path, DataFrame)
    if max_rows !== nothing && nrow(df) > max_rows
        df = df[1:max_rows, :]
    end
    col_match = findfirst(n -> lowercase(String(n)) == lowercase(bus_name), names(df))
    isnothing(col_match) && error("No price column found for bus $(bus_name) in $(path)")
    bus_col = names(df)[col_match]
    timestamps = collect(df[!, "DateTime"])
    values = collect(Float64, df[!, bus_col])
    ts = TimeArray(timestamps, values, ["value"])
    return PSY.SingleTimeSeries(ts_name, ts)
end

function _validate_scalar_series_contract(
    ts::PSY.SingleTimeSeries;
    min_length::Union{Nothing, Int} = nothing,
    expected_resolution = nothing,
    expected_start = nothing,
    label::String = "series",
)
    data = IS.get_data(ts)
    timestamps = collect(getfield(data, :timestamp))
    values = getfield(data, :values)
    n = size(values, 1)
    if !isnothing(min_length) && n < min_length
        error("$(label) has length $(n), but at least $(min_length) points are required")
    end
    if !isnothing(expected_resolution) && IS.get_resolution(ts) != expected_resolution
        error(
            "$(label) has resolution $(IS.get_resolution(ts)); expected $(expected_resolution). " *
            "Update the fixture CSV to be directly PSY-ingestible.",
        )
    end
    if !isnothing(expected_start) && first(timestamps) != expected_start
        error("$(label) starts at $(first(timestamps)); expected $(expected_start)")
    end
    return
end

function _select_price_fixture(base_name::String, n_steps::Int)
    dir = joinpath(TEST_DIR, "inputs")
    short = joinpath(dir, base_name * "_300.csv")
    # Prefer the 300-row harness when it covers the horizon so global `transform_single_time_series!`
    # sees consistent metadata; `_build_scalar_time_series_from_csv(...; max_rows=...)` truncates
    # (e.g. 300 → 288) so DA bid indices match RT steps without mixing full-RTS CSV counts.
    if n_steps <= 300 && isfile(short)
        return short
    end
    return joinpath(dir, base_name * ".csv")
end

function attach_hybrid_market_time_series!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem;
    bus_name::String = "chuhsi",
    attach_services::Bool = false,
    rt_steps::Int = 288,
    da_steps::Int = 24,
    injection_rt_steps::Int = rt_steps,
    use_rt_resolution_for_da::Bool = false,
)
    rt_price = _build_scalar_time_series_from_csv(
        _select_price_fixture("$(bus_name)_RT_prices", rt_steps),
        bus_name,
        HSS.hybrid_energy_price_time_series_name(HSS.REAL_TIME_TIME_SERIES_KEY);
        max_rows = rt_steps,
    )
    _validate_scalar_series_contract(
        rt_price;
        min_length = rt_steps,
        label = "RT market price fixture",
    )
    rt_data = IS.get_data(rt_price)
    rt_resolution = IS.get_resolution(rt_price)
    expected_da_res = use_rt_resolution_for_da ? rt_resolution : Dates.Hour(1)
    da_file = if use_rt_resolution_for_da
        _select_price_fixture("$(bus_name)_DA_prices_5min", rt_steps)
    else
        joinpath(TEST_DIR, "inputs/$(bus_name)_DA_prices.csv")
    end
    da_price = _build_scalar_time_series_from_csv(
        da_file,
        bus_name,
        HSS.hybrid_energy_price_time_series_name(HSS.DAY_AHEAD_TIME_SERIES_KEY);
        max_rows = use_rt_resolution_for_da ? rt_steps : da_steps,
    )
    _validate_scalar_series_contract(
        da_price;
        min_length = use_rt_resolution_for_da ? rt_steps : da_steps,
        expected_resolution = expected_da_res,
        expected_start = first(getfield(rt_data, :timestamp)),
        label = "DA market price fixture",
    )
    PSY.add_time_series!(sys, hybrid, da_price)
    PSY.add_time_series!(sys, hybrid, rt_price)

    if attach_services
        reg_up_file = if use_rt_resolution_for_da
            _select_price_fixture("$(bus_name)_RegUp_prices_5min", rt_steps)
        else
            joinpath(TEST_DIR, "inputs/$(bus_name)_RegUp_prices.csv")
        end
        reg_up = _build_scalar_time_series_from_csv(
            reg_up_file,
            bus_name,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Reg_Up",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            );
            max_rows = use_rt_resolution_for_da ? rt_steps : da_steps,
        )
        _validate_scalar_series_contract(
            reg_up;
            min_length = use_rt_resolution_for_da ? rt_steps : da_steps,
            expected_resolution = expected_da_res,
            expected_start = first(getfield(rt_data, :timestamp)),
            label = "Reg_Up market price fixture",
        )
        reg_dn_file = if use_rt_resolution_for_da
            _select_price_fixture("$(bus_name)_RegDown_prices_5min", rt_steps)
        else
            joinpath(TEST_DIR, "inputs/$(bus_name)_RegDown_prices.csv")
        end
        reg_dn = _build_scalar_time_series_from_csv(
            reg_dn_file,
            bus_name,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Reg_Down",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            );
            max_rows = use_rt_resolution_for_da ? rt_steps : da_steps,
        )
        _validate_scalar_series_contract(
            reg_dn;
            min_length = use_rt_resolution_for_da ? rt_steps : da_steps,
            expected_resolution = expected_da_res,
            expected_start = first(getfield(rt_data, :timestamp)),
            label = "Reg_Down market price fixture",
        )
        spin_file = if use_rt_resolution_for_da
            _select_price_fixture("$(bus_name)_Spin_prices_5min", rt_steps)
        else
            joinpath(TEST_DIR, "inputs/$(bus_name)_Spin_prices.csv")
        end
        spin = _build_scalar_time_series_from_csv(
            spin_file,
            bus_name,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Spin_Up_R3",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            );
            max_rows = use_rt_resolution_for_da ? rt_steps : da_steps,
        )
        _validate_scalar_series_contract(
            spin;
            min_length = use_rt_resolution_for_da ? rt_steps : da_steps,
            expected_resolution = expected_da_res,
            expected_start = first(getfield(rt_data, :timestamp)),
            label = "Spin_Up_R3 market price fixture",
        )
        PSY.add_time_series!(sys, hybrid, reg_up)
        PSY.add_time_series!(sys, hybrid, reg_dn)
        PSY.add_time_series!(sys, hybrid, spin)
    end
    # Merchant models slice contiguous profile values from the wrapped SingleTimeSeries on the
    # hybrid; elongate subcomponent copies so the stored series spans `rt_steps` at `step`.
    # Cap profile length to the RT price series length so global transforms see one horizon count
    # (caller may pass injection_rt_steps > rt_steps for legacy reasons).
    profile_steps = min(injection_rt_steps, rt_steps)
    ensure_hybrid_injection_profiles!(
        sys,
        hybrid,
        profile_steps,
        Dates.Minute(5);
        start_time = first(getfield(rt_data, :timestamp)),
    )
    keep_names = Set([
        "RenewableDispatch__max_active_power",
        "PowerLoad__max_active_power",
        HSS.hybrid_energy_price_time_series_name(HSS.DAY_AHEAD_TIME_SERIES_KEY),
        HSS.hybrid_energy_price_time_series_name(HSS.REAL_TIME_TIME_SERIES_KEY),
    ])
    if attach_services
        push!(
            keep_names,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Reg_Up",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            ),
        )
        push!(
            keep_names,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Reg_Down",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            ),
        )
        push!(
            keep_names,
            HSS.hybrid_ancillary_service_price_time_series_name(
                "Spin_Up_R3",
                HSS.DAY_AHEAD_TIME_SERIES_KEY,
            ),
        )
    end
    prune_hybrid_single_time_series!(sys, hybrid; keep_names)
    kept_series = collect(PSY.get_time_series_multiple(hybrid; type = IS.SingleTimeSeries))
    PSY.remove_time_series!(sys, IS.DeterministicSingleTimeSeries)
    PSY.remove_time_series!(sys, IS.SingleTimeSeries)
    for ts in kept_series
        PSY.add_time_series!(sys, hybrid, ts)
    end
    return
end

function prune_hybrid_single_time_series!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem;
    keep_names::Set{String},
)
    for ts in collect(PSY.get_time_series_multiple(hybrid; type = IS.SingleTimeSeries))
        nm = IS.get_name(ts)
        nm in keep_names && continue
        PSY.remove_time_series!(
            sys,
            IS.SingleTimeSeries,
            hybrid,
            nm;
            resolution = IS.get_resolution(ts),
        )
    end
    return
end

function _remove_all_hybrid_time_series_named!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem,
    ts_name::String,
)
    for ts in collect(PSY.get_time_series_multiple(hybrid; name = ts_name))
        T = typeof(ts)
        nm = IS.get_name(ts)
        if ts isa IS.DeterministicSingleTimeSeries
            PSY.remove_time_series!(
                sys,
                T,
                hybrid,
                nm;
                resolution = IS.get_resolution(ts),
                interval = IS.get_interval(ts),
            )
        else
            PSY.remove_time_series!(
                sys,
                T,
                hybrid,
                nm;
                resolution = IS.get_resolution(ts),
            )
        end
    end
    return
end

function _read_hybrid_profile_underlying_values(hybrid::PSY.HybridSystem, ts_name::String)
    try
        sts = PSY.get_time_series(IS.SingleTimeSeries, hybrid, ts_name)
        ta = IS.get_data(sts)
        ts = collect(getfield(ta, :timestamp))
        vm = getfield(ta, :values)
        vals = ndims(vm) == 1 ? Vector(vm) : vec(vm[:, 1])
        return vals, first(ts)
    catch
        for ts in collect(
            PSY.get_time_series_multiple(
                hybrid;
                name = ts_name,
                type = IS.DeterministicSingleTimeSeries,
            ),
        )
            sts = IS.get_single_time_series(ts)
            ta = IS.get_data(sts)
            tsvec = collect(getfield(ta, :timestamp))
            vm = getfield(ta, :values)
            vals = ndims(vm) == 1 ? Vector(vm) : vec(vm[:, 1])
            return vals, first(tsvec)
        end
    end
    return nothing, nothing
end

"""
Remove every `InfrastructureSystems.SingleTimeSeries` from `sys` so a later
`attach_hybrid_market_time_series!` call provides the only static series for
`transform_single_time_series!`. This avoids `ConflictingInputsError` when RTS still carries
unconverted static series whose forecast-window counts differ from the hybrid-attached CSVs.
"""
function _strip_single_time_series_from_owner!(sys::PSY.System, owner)
    for ts in collect(PSY.get_time_series_multiple(owner; type = IS.SingleTimeSeries))
        nm = IS.get_name(ts)
        res = IS.get_resolution(ts)
        try
            PSY.remove_time_series!(sys, IS.SingleTimeSeries, owner, nm; resolution = res)
        catch
        end
    end
    return
end

function strip_all_single_time_series!(sys::PSY.System)
    # Only visit IS time-series owners (excludes buses and other components without TS support).
    for comp in IS.iterate_components_with_time_series(sys.data)
        _strip_single_time_series_from_owner!(sys, comp)
    end
    for attr in IS.iterate_supplemental_attributes_with_time_series(sys.data)
        _strip_single_time_series_from_owner!(sys, attr)
    end
    return
end

"""
Remove `SingleTimeSeries` from non-hybrid owners only. Merchant tests rely on hybrid-attached
series; pruning other static series avoids global transform conflicts at 5-minute model interval.
"""
function strip_non_hybrid_single_time_series!(sys::PSY.System)
    for comp in IS.iterate_components_with_time_series(sys.data)
        comp isa PSY.HybridSystem && continue
        _strip_single_time_series_from_owner!(sys, comp)
    end
    for attr in IS.iterate_supplemental_attributes_with_time_series(sys.data)
        _strip_single_time_series_from_owner!(sys, attr)
    end
    return
end

"""
Ensure `RenewableDispatch__max_active_power` / `PowerLoad__max_active_power` on `hybrid` store
exactly `target_steps` contiguous samples at `step`. Shorter series are tiled, longer series are
truncated. This keeps hybrid-attached STS counts aligned for deterministic transforms.
"""
function ensure_hybrid_injection_profiles!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem,
    target_steps::Int,
    step::Dates.Period = Dates.Minute(5);
    start_time::Union{Nothing, Dates.DateTime} = nothing,
)
    if PSY.get_renewable_unit(hybrid) !== nothing
        _ensure_one_hybrid_profile!(
            sys,
            hybrid,
            "RenewableDispatch__max_active_power",
            target_steps,
            step,
            start_time,
        )
    end
    if PSY.get_electric_load(hybrid) !== nothing
        _ensure_one_hybrid_profile!(
            sys,
            hybrid,
            "PowerLoad__max_active_power",
            target_steps,
            step,
            start_time,
        )
    end
    return
end

function _ensure_one_hybrid_profile!(
    sys::PSY.System,
    hybrid::PSY.HybridSystem,
    ts_name::String,
    target_steps::Int,
    step::Dates.Period,
    start_time::Union{Nothing, Dates.DateTime},
)
    if isempty(collect(PSY.get_time_series_multiple(hybrid; name = ts_name)))
        return
    end
    vals, t0 = _read_hybrid_profile_underlying_values(hybrid, ts_name)
    (vals === nothing) && return
    new_vals = repeat(vals, cld(target_steps, length(vals)))[1:target_steps]
    t_start = isnothing(start_time) ? t0 : start_time
    new_timestamps = [t_start + (i - 1) * step for i in 1:target_steps]
    ta = TimeArray(new_timestamps, new_vals, ["value"])
    new_sts = PSY.SingleTimeSeries(ts_name, ta)
    _remove_all_hybrid_time_series_named!(sys, hybrid, ts_name)
    PSY.add_time_series!(sys, hybrid, new_sts)
    return
end
