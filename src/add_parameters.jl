###################################################################
################### Decision Model Parameters #####################
###################################################################

function _hybrid_profile_initial_values(
    container::PSI.OptimizationContainer,
    ts_type,
    device::PSY.HybridSystem,
    ts_name::String,
    model_resolution,
    model_interval,
    feat_kw::NamedTuple,
)
    initial_time = PSI.get_initial_time(container)
    time_steps = PSI.get_time_steps(container)
    forecast = PSY.get_time_series(
        ts_type,
        device,
        ts_name;
        start_time = initial_time,
        count = 1,
        interval = PSI._to_is_interval(model_interval),
        resolution = PSI._to_is_resolution(model_resolution),
        feat_kw...,
    )
    return IS.get_time_series_values(
        device,
        forecast;
        start_time = initial_time,
        len = length(time_steps),
        ignore_scaling_factors = true,
    )
end

"""
Read injection profile points (`RenewableDispatch__max_active_power`, `PowerLoad__max_active_power`)
from the wrapped `SingleTimeSeries` stored on the hybrid, slicing `length(time_steps)` contiguous
values from `start_time`. This avoids `DeterministicSingleTimeSeries` forecast windows that may
only span a short sub-interval of the underlying data.
"""
function _hybrid_profile_parameter_slice(
    container::PSI.OptimizationContainer,
    device::PSY.HybridSystem,
    ts_name::String,
    start_time::Dates.DateTime;
    feat_kw::NamedTuple = (;),
)
    n = length(PSI.get_time_steps(container))
    sts = _unwrap_hybrid_underlying_single_time_series(container, device, ts_name, feat_kw)
    ta = IS.get_data(sts)
    timestamps = collect(getfield(ta, :timestamp))
    valmatrix = getfield(ta, :values)
    vals = ndims(valmatrix) == 1 ? Vector(valmatrix) : vec(valmatrix[:, 1])
    start_ix = PSI.find_timestamp_index(timestamps, start_time)
    start_ix + n - 1 <= length(vals) ||
        error(
            "Hybrid profile $(repr(ts_name)) on $(PSY.get_name(device)) ends before step $(n) at $(start_time); " *
            "ensure the underlying SingleTimeSeries spans the optimization horizon (see test helpers `ensure_hybrid_injection_profiles!`).",
        )
    return vals[start_ix:(start_ix + n - 1)]
end

function _get_hybrid_profile_parameter_values(
    container::PSI.OptimizationContainer,
    device::PSY.HybridSystem,
    ts_name::String;
    feat_kw::NamedTuple = (;),
)
    return _hybrid_profile_parameter_slice(
        container,
        device,
        ts_name,
        PSI.get_initial_time(container);
        feat_kw,
    )
end

function _unwrap_hybrid_underlying_single_time_series(
    container::PSI.OptimizationContainer,
    device::PSY.HybridSystem,
    ts_name::String,
    feat_kw::NamedTuple,
)
    settings = PSI.get_settings(container)
    res_kw = PSI._to_is_resolution(PSI.get_resolution(settings))
    int_kw = PSI._to_is_interval(PSI.get_interval(settings))
    try
        if isempty(feat_kw)
            return PSY.get_time_series(IS.SingleTimeSeries, device, ts_name)
        end
        return PSY.get_time_series(IS.SingleTimeSeries, device, ts_name; feat_kw...)
    catch e
        # IS throws ArgumentError when the series is missing or ambiguous at this
        # type; only then fall back to the transformed DeterministicSingleTimeSeries.
        e isa ArgumentError || rethrow()
        if isempty(feat_kw)
            dst = PSY.get_time_series(
                IS.DeterministicSingleTimeSeries,
                device,
                ts_name;
                resolution = res_kw,
                interval = int_kw,
            )
        else
            dst = PSY.get_time_series(
                IS.DeterministicSingleTimeSeries,
                device,
                ts_name;
                resolution = res_kw,
                interval = int_kw,
                feat_kw...,
            )
        end
        return IS.get_single_time_series(dst)
    end
end

function _add_time_series_parameters(
    container::PSI.OptimizationContainer,
    ts_name::String,
    param,
    devices::AbstractVector{<:PSY.HybridSystem};
    timeseries_key::Union{Nothing, String} = nothing,
)
    # Injection profiles live as static `SingleTimeSeries` on the hybrid; registering them as the
    # system default `DeterministicSingleTimeSeries` breaks simulation updates (HDF5 slice vs full
    # horizon) when PSI advances `current_time`.
    ts_type =
        if timeseries_key === nothing
            PSY.SingleTimeSeries
        else
            PSI.get_default_time_series_type(container)
        end
    time_steps = PSI.get_time_steps(container)
    settings = PSI.get_settings(container)
    model_resolution = PSI.get_resolution(settings)
    model_interval = PSI.get_interval(settings)
    feat_kw =
        if timeseries_key === nothing
            (;)
        else
            (; HYBRID_TIME_SERIES_FEATURE_KEY => timeseries_key)
        end

    device_names = String[]
    initial_values = Dict{String, AbstractArray}()
    for device in devices
        push!(device_names, PSY.get_name(device))
        ts_metadata =
            if ts_type === PSY.SingleTimeSeries
                IS.get_time_series_metadata(
                    PSY.SingleTimeSeries,
                    device,
                    ts_name;
                    resolution = PSI._to_is_resolution(model_resolution),
                    feat_kw...,
                )
            else
                IS.get_time_series_metadata(
                    ts_type,
                    device,
                    ts_name;
                    resolution = PSI._to_is_resolution(model_resolution),
                    interval = PSI._to_is_interval(model_interval),
                    feat_kw...,
                )
            end
        ts_uuid = string(IS.get_time_series_uuid(ts_metadata))
        if !(ts_uuid in keys(initial_values))
            initial_values[ts_uuid] =
                if timeseries_key === nothing
                    _get_hybrid_profile_parameter_values(
                        container,
                        device,
                        ts_name;
                        feat_kw,
                    )
                else
                    _hybrid_profile_initial_values(
                        container,
                        ts_type,
                        device,
                        ts_name,
                        model_resolution,
                        model_interval,
                        feat_kw,
                    )
                end
        end
    end

    param_container = PSI.add_param_container!(
        container,
        param,
        PSY.HybridSystem,
        ts_type,
        ts_name,
        collect(keys(initial_values)),
        device_names,
        (),  # additional_axes: no extra axes for RenewablePowerTimeSeries
        time_steps,
    )
    jump_model = PSI.get_jump_model(container)

    for (ts_uuid, ts_values) in initial_values
        for step in time_steps
            PSI.set_parameter!(param_container, jump_model, ts_values[step], ts_uuid, step)
        end
    end

    for device in devices
        name = PSY.get_name(device)
        multiplier = _get_hybrid_ts_multiplier(param, device)
        for step in time_steps
            PSI.set_multiplier!(param_container, multiplier, name, step)
        end
        ts_metadata =
            if ts_type === PSY.SingleTimeSeries
                IS.get_time_series_metadata(
                    PSY.SingleTimeSeries,
                    device,
                    ts_name;
                    resolution = PSI._to_is_resolution(model_resolution),
                    feat_kw...,
                )
            else
                IS.get_time_series_metadata(
                    ts_type,
                    device,
                    ts_name;
                    resolution = PSI._to_is_resolution(model_resolution),
                    interval = PSI._to_is_interval(model_interval),
                    feat_kw...,
                )
            end
        PSI.add_component_name!(
            PSI.get_attributes(param_container),
            name,
            string(IS.get_time_series_uuid(ts_metadata)),
        )
    end
    return
end

function PSI._update_parameter_values!(
    parameter_array::AbstractArray{T},
    ::P,
    attributes::PSI.TimeSeriesAttributes{PSY.SingleTimeSeries},
    ::Type{PSY.HybridSystem},
    model::PSI.DecisionModel,
    ::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {
    T <: Union{JuMP.VariableRef, Float64},
    P <: Union{RenewablePowerTimeSeries, ElectricLoadTimeSeries},
}
    container = PSI.get_optimization_container(model)
    ts_name = PSI.get_time_series_name(attributes)
    current_time = PSI.get_current_time(model)
    template = PSI.get_template(model)
    device_model = PSI.get_model(template, PSY.HybridSystem)
    components = PSI.get_available_components(device_model, PSI.get_system(model))
    # The parameter is only registered for the hybrids that own this profile
    # (e.g. hybrids with a renewable unit); skip the rest like PSI's generic method does.
    registered_names = PSI.get_component_names(attributes)
    ts_uuids = Set{String}()
    for component in components
        PSY.get_name(component) in registered_names || continue
        ts_uuid = PSI._get_ts_uuid(attributes, PSY.get_name(component))
        if !(ts_uuid in ts_uuids)
            ts_vector = _hybrid_profile_parameter_slice(
                container,
                component,
                ts_name,
                current_time,
            )
            for (t, value) in enumerate(ts_vector)
                if !isfinite(value)
                    error(
                        "Hybrid profile $(repr(ts_name)) has non-finite value at step $t for $(PSY.get_name(component))",
                    )
                end
                PSI._set_param_value!(parameter_array, value, ts_uuid, t)
            end
            push!(ts_uuids, ts_uuid)
        end
    end
    return
end

function _get_hybrid_ts_multiplier(::RenewablePowerTimeSeries, device::PSY.HybridSystem)
    return PSY.get_max_active_power(PSY.get_renewable_unit(device))
end

function _get_hybrid_ts_multiplier(::ElectricLoadTimeSeries, device::PSY.HybridSystem)
    return PSY.get_max_active_power(PSY.get_electric_load(device))
end

function _get_hybrid_scalar_forecast_values(
    container::PSI.OptimizationContainer,
    hybrid::PSY.HybridSystem,
    ts_full_name::String;
    forecast_time::Union{Nothing, Dates.DateTime} = nothing,
    n_steps::Union{Nothing, Int} = nothing,
)
    initial_time = something(forecast_time, PSI.get_initial_time(container))
    n = something(n_steps, length(PSI.get_time_steps(container)))
    # Merchant hybrid prices are attached as `SingleTimeSeries` with explicit names; read the
    # contiguous stored array directly so we are not limited by a shorter deterministic forecast
    # window from system-wide transforms.
    ts = PSY.get_time_series(IS.SingleTimeSeries, hybrid, ts_full_name)
    data = IS.get_data(ts)
    timestamps = getfield(data, :timestamp)
    values = getfield(data, :values)
    start_ix = PSI.find_timestamp_index(timestamps, initial_time)
    end_ix = min(size(values, 1), start_ix + n - 1)
    end_ix < start_ix + n - 1 && error(
        "Scalar series $(repr(ts_full_name)) ends before step $(n) at $(initial_time) on $(PSY.get_name(hybrid))",
    )
    return vec(values[start_ix:end_ix, 1])
end

# Multipliers consider that the objective function is a Maximization problem
# But the default direction in PSI is Min.
_get_multiplier(::Type{EnergyDABidOut}, ::DayAheadEnergyPrice) = -1.0
_get_multiplier(::Type{EnergyDABidIn}, ::DayAheadEnergyPrice) = 1.0
_get_multiplier(::Type{EnergyRTBidOut}, ::RealTimeEnergyPrice) = -1.0
_get_multiplier(::Type{EnergyRTBidIn}, ::RealTimeEnergyPrice) = 1.0
_get_multiplier(::Type{EnergyDABidOut}, ::RealTimeEnergyPrice) = 1.0
_get_multiplier(::Type{EnergyDABidIn}, ::RealTimeEnergyPrice) = -1.0
_get_multiplier(::Type{BidReserveVariableOut}, ::AncillaryServicePrice) = 1.0
_get_multiplier(::Type{BidReserveVariableIn}, ::AncillaryServicePrice) = 1.0

# DA and RT Prices
function _add_price_time_series_parameters(
    container::PSI.OptimizationContainer,
    param::Union{RealTimeEnergyPrice, DayAheadEnergyPrice},
    ts_full_name::String,
    devices::Vector{PSY.HybridSystem},
    vars::Vector,
)
    time_steps =
        if param isa DayAheadEnergyPrice
            merchant_da_time_step_range(container, first(devices))
        else
            PSI.get_time_steps(container)
        end
    n_price = length(time_steps)
    first_values = _get_hybrid_scalar_forecast_values(
        container,
        first(devices),
        ts_full_name;
        n_steps = n_price,
    )
    device_names = PSY.get_name.(devices)
    jump_model = PSI.get_jump_model(container)

    for var in vars
        param_container = PSI.add_param_container!(
            container,
            param,
            PSY.HybridSystem,
            (var,),
            PSI.SOSStatusVariable.NO_VARIABLE,
            false,
            Float64,
            device_names,
            time_steps;
            meta = "$var",
        )

        for device in devices
            price_value = _get_hybrid_scalar_forecast_values(
                container,
                device,
                ts_full_name;
                n_steps = n_price,
            )
            name = PSY.get_name(device)
            for step in time_steps
                PSI.set_parameter!(
                    param_container,
                    jump_model,
                    price_value[step],
                    name,
                    step,
                )
                PSI.set_multiplier!(
                    param_container,
                    _get_multiplier(var, param),
                    name,
                    step,
                )
            end
        end
    end
    return
end

# Ancillary Service Prices
function _add_price_time_series_parameters(
    container::PSI.OptimizationContainer,
    param::AncillaryServicePrice,
    ts_key::String,
    devices::Vector{PSY.HybridSystem},
    vars::Vector,
)
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
    isempty(services) && return
    first_service = PSY.get_name(first(services))
    time_steps = merchant_da_time_step_range(container, first(devices))
    n_price = length(time_steps)
    first_values = _get_hybrid_scalar_forecast_values(
        container,
        first(devices),
        hybrid_ancillary_service_price_time_series_name(first_service, ts_key);
        n_steps = n_price,
    )
    device_names = PSY.get_name.(devices)
    jump_model = PSI.get_jump_model(container)
    for var in vars
        for service in services
            service_name = PSY.get_name(service)
            param_container = PSI.add_param_container!(
                container,
                param,
                PSY.HybridSystem,
                (var,),
                PSI.SOSStatusVariable.NO_VARIABLE,
                false,
                Float64,
                device_names,
                time_steps;
                meta = "$(var)_$(service_name)",
            )

            for device in devices
                price_value = _get_hybrid_scalar_forecast_values(
                    container,
                    device,
                    hybrid_ancillary_service_price_time_series_name(service_name, ts_key);
                    n_steps = n_price,
                )
                name = PSY.get_name(device)
                for step in time_steps
                    PSI.set_parameter!(
                        param_container,
                        jump_model,
                        price_value[step],
                        name,
                        step,
                    )
                    PSI.set_multiplier!(
                        param_container,
                        _get_multiplier(var, param),
                        name,
                        step,
                    )
                end
            end
        end
    end
    return
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::RenewablePowerTimeSeries,
    devices::AbstractVector{<:PSY.HybridSystem},
    ts_name = "RenewableDispatch__max_active_power";
    timeseries_key::Union{Nothing, String} = nothing,
)
    _add_time_series_parameters(container, ts_name, param, devices; timeseries_key)
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::ElectricLoadTimeSeries,
    devices::AbstractVector{<:PSY.HybridSystem},
    ts_name = "PowerLoad__max_active_power";
    timeseries_key::Union{Nothing, String} = nothing,
)
    _add_time_series_parameters(container, ts_name, param, devices; timeseries_key)
    return
end

function PSI._add_parameters!(
    container::PSI.OptimizationContainer,
    param::T,
    devices::U,
    model::PSI.DeviceModel{D, W},
) where {
    T <: Union{RenewablePowerTimeSeries, ElectricLoadTimeSeries},
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    add_time_series_parameters!(
        container,
        param,
        collect(devices);
        timeseries_key = nothing,
    )
    return
end

function PSI.add_parameters!(
    container::PSI.OptimizationContainer,
    param::T,
    devices::Vector{PSY.HybridSystem},
    ::W,
) where {
    T <: Union{DayAheadEnergyPrice, RealTimeEnergyPrice, AncillaryServicePrice},
    W <: Union{MerchantModelEnergyOnly, MerchantModelWithReserves},
}
    add_time_series_parameters!(container, param, devices)
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::DayAheadEnergyPrice,
    devices::Vector{PSY.HybridSystem},
)
    ts_key = get_day_ahead_time_series_key(container)
    vars = [EnergyDABidOut, EnergyDABidIn]
    _add_price_time_series_parameters(
        container,
        param,
        hybrid_energy_price_time_series_name(ts_key),
        devices,
        vars,
    )
    return
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::RealTimeEnergyPrice,
    devices::Vector{PSY.HybridSystem},
)
    ts_key = get_real_time_time_series_key(container)
    vars = [EnergyDABidOut, EnergyDABidIn, EnergyRTBidOut, EnergyRTBidIn]
    _add_price_time_series_parameters(
        container,
        param,
        hybrid_energy_price_time_series_name(ts_key),
        devices,
        vars,
    )
    return
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::AncillaryServicePrice,
    devices::Vector{PSY.HybridSystem},
)
    ts_key = get_day_ahead_time_series_key(container)
    vars = [BidReserveVariableOut, BidReserveVariableIn]
    _add_price_time_series_parameters(container, param, ts_key, devices, vars)
    return
end

function PSI.update_parameter_values!(
    model::PSI.DecisionModel{T},
    key::PSI.ParameterKey{U, PSY.HybridSystem},
    ::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {T <: HybridDecisionProblem, U <: Union{DayAheadEnergyPrice, RealTimeEnergyPrice}}
    container = PSI.get_optimization_container(model)
    @assert !PSI.is_synchronized(container)
    _update_parameter_values!(model, key)
    return
end

"""
Clamp decision-state writes for merchant hybrid price parameters when store horizon extends
beyond the state buffer length during rolling simulation updates.
"""
function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.ParameterKey{T, PSY.HybridSystem},
    store_data::PSI.DenseAxisArray{Float64, 2},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
) where {T <: Union{DayAheadEnergyPrice, RealTimeEnergyPrice}}
    state_data = PSI.get_decision_state_data(state, key)
    column_names = PSI.get_column_names(key, state_data)[1]
    model_resolution = PSI.get_resolution(model_params)
    state_resolution = PSI.get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    PSI.IS.@assert_op resolution_ratio >= 1

    if simulation_time > PSI.get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .= range(
            simulation_time;
            step = state_resolution,
            length = PSI.get_num_rows(state_data),
        )
    else
        state_data_index = PSI.find_timestamp_index(state_timestamps, simulation_time)
    end

    max_state_index = PSI.get_num_rows(state_data)
    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[2]
    PSI.set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_data_index > max_state_index && break
        state_range = state_data_index:min(max_state_index, state_data_index + offset)
        for name in column_names, i in state_range
            state_data.values[name, i] = store_data[name, t]
        end
        PSI.set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end

"""
During `Simulation` execution, PSI calls `_update_parameter_values!(..., ::ObjectiveFunctionParameter, ...)`
from `update_cost_parameters.jl`, which uses `handle_variable_cost_parameter` with
`PSY.get_operation_cost(component)`. Merchant hybrids use `MarketBidCost(nothing)`; energy prices
are read from hybrid-attached scalar `"HybridSystem__energy_price"` time series (keyed DA/RT) instead.
This hooks the generic simulation update path into the same hybrid scalar forecast logic as
`update_parameter_values!(..., ::InMemoryDataset)`.
"""
function _merchant_hybrid_price_parameter_key(
    container::PSI.OptimizationContainer,
    parameter_array,
    ::Type{P},
) where {P <: Union{DayAheadEnergyPrice, RealTimeEnergyPrice}}
    for (k, v) in PSI.get_parameters(container)
        (k isa ISOPT.ParameterKey{P, PSY.HybridSystem}) || continue
        if PSI.get_parameter_array(v) === parameter_array
            return k
        end
    end
    return nothing
end

function PSI._update_parameter_values!(
    parameter_array::JuMP.Containers.DenseAxisArray{Float64, 2},
    ::DayAheadEnergyPrice,
    parameter_multiplier::JuMP.Containers.DenseAxisArray{Float64, 2},
    attributes::PSI.CostFunctionAttributes,
    ::Type{PSY.HybridSystem},
    model::PSI.DecisionModel{T},
    input::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {T <: HybridDecisionProblem}
    container = PSI.get_optimization_container(model)
    key = _merchant_hybrid_price_parameter_key(
        container,
        parameter_array,
        DayAheadEnergyPrice,
    )
    if key === nothing
        error(
            "Could not match DayAheadEnergyPrice parameter array to a registered HybridSystem parameter key",
        )
    end
    _update_parameter_values!(model, key)
    return
end

function PSI._update_parameter_values!(
    parameter_array::JuMP.Containers.DenseAxisArray{Float64, 2},
    ::RealTimeEnergyPrice,
    parameter_multiplier::JuMP.Containers.DenseAxisArray{Float64, 2},
    attributes::PSI.CostFunctionAttributes,
    ::Type{PSY.HybridSystem},
    model::PSI.DecisionModel{T},
    input::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {T <: HybridDecisionProblem}
    container = PSI.get_optimization_container(model)
    key = _merchant_hybrid_price_parameter_key(
        container,
        parameter_array,
        RealTimeEnergyPrice,
    )
    if key === nothing
        error(
            "Could not match RealTimeEnergyPrice parameter array to a registered HybridSystem parameter key",
        )
    end
    _update_parameter_values!(model, key)
    return
end

function _update_parameter_values!(
    model::PSI.DecisionModel{T},
    key::PSI.ParameterKey{DayAheadEnergyPrice, PSY.HybridSystem},
) where {T <: HybridDecisionProblem}
    initial_forecast_time = PSI.get_current_time(model)
    container = PSI.get_optimization_container(model)
    parameter_array = PSI.get_parameter_array(container, key)
    parameter_multiplier = PSI.get_parameter_multiplier_array(container, key)
    attributes = PSI.get_parameter_attributes(container, key)
    components = PSI.get_available_components(PSY.HybridSystem, PSI.get_system(model))
    ts_key = get_day_ahead_time_series_key(container)
    n_da = min(
        length(merchant_da_time_step_range(container, first(components))),
        length(PSI.get_time_steps(container)),
    )
    for component in components
        λ = _get_hybrid_scalar_forecast_values(
            container,
            component,
            hybrid_energy_price_time_series_name(ts_key);
            forecast_time = PSI.get_current_time(model),
            n_steps = n_da,
        )
        name = PSY.get_name(component)
        for (t, value) in enumerate(λ)
            # Since the DA variables are hourly, this will revert the dt multiplication
            PSI._set_param_value!(parameter_array, value * 1.0 * 100.0, name, t)
            PSI.update_variable_cost!(
                DayAheadEnergyPrice(),
                container,
                parameter_array,
                parameter_multiplier,
                attributes,
                component,
                t,
            )
        end
    end
    return
end

# The definition of these two methods is required because of the two resolutions used
# in the model. Updating the real-time price requires using the mapping. Normally we don't
# want to expose this level of detail to users wanting to make extensions
function _merchant_real_time_price_variable_type(meta::String)
    meta == string(nameof(EnergyDABidOut)) && return EnergyDABidOut
    meta == string(nameof(EnergyDABidIn)) && return EnergyDABidIn
    meta == string(nameof(EnergyRTBidOut)) && return EnergyRTBidOut
    meta == string(nameof(EnergyRTBidIn)) && return EnergyRTBidIn
    error("Unknown RealTimeEnergyPrice parameter meta: $(repr(meta))")
end

function _update_parameter_values!(
    model::PSI.DecisionModel{T},
    key::PSI.ParameterKey{RealTimeEnergyPrice, PSY.HybridSystem},
) where {T <: HybridDecisionProblem}
    container = PSI.get_optimization_container(model)
    resolution = PSI.get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / PSI.SECONDS_IN_HOUR
    da_len = size(PSI.get_variable(container, EnergyDABidOut(), PSY.HybridSystem), 2)
    rt_len = size(PSI.get_variable(container, EnergyRTBidOut(), PSY.HybridSystem), 2)
    tmap = merchant_rt_to_da_tmap(rt_len, da_len)
    parameter_array = PSI.get_parameter_array(container, key)
    attributes = PSI.get_parameter_attributes(container, key)
    components = PSI.get_available_components(PSY.HybridSystem, PSI.get_system(model))
    Vtype = _merchant_real_time_price_variable_type(key.meta)
    variable = PSI.get_variable(container, Vtype(), PSY.HybridSystem)
    parameter_multiplier = PSI.get_parameter_multiplier_array(container, key)
    ts_key = get_real_time_time_series_key(container)
    for component in components
        λ = _get_hybrid_scalar_forecast_values(
            container,
            component,
            hybrid_energy_price_time_series_name(ts_key);
            forecast_time = PSI.get_current_time(model),
        )
        name = PSY.get_name(component)
        for (t, value) in enumerate(λ)
            mul_ = parameter_multiplier[name, t] * 100.0
            _val = value * dt * mul_
            PSI._set_param_value!(parameter_array, _val, name, t)
            if Vtype ∈ (EnergyDABidOut, EnergyDABidIn)
                hy_cost = -variable[name, tmap[t]] * _val
            else
                hy_cost = variable[name, t] * _val
            end
            PSI.add_to_objective_variant_expression!(container, hy_cost)
            PSI.set_expression!(
                container,
                PSI.ProductionCostExpression,
                hy_cost,
                component,
                t,
            )
        end
    end
    return
end

function PSI._update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::PSI.VariableValueAttributes{PSI.VariableKey{U, PSY.HybridSystem}},
    ::Type{PSY.HybridSystem},
    model::PSI.DecisionModel,
    state::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {
    T <: Union{JuMP.VariableRef, Float64},
    U <: Union{CyclingDischargeUsage, CyclingChargeUsage},
}
    current_time = get_current_time(model)
    state_values = get_dataset_values(state, get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    model_resolution = get_resolution(model)
    state_data = get_dataset(state, get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = get_num_rows(state_data)
    if model_resolution < state_data.resolution
        t_step = 1
    else
        t_step = model_resolution ÷ state_data.resolution
    end
    state_data_index = find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time; step = model_resolution, length = time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + t_step)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            state_value = state_values[name, state_data_index]
            if !isfinite(state_value)
                error(
                    "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(state_value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            _set_param_value_hss!(parameter_array, state_value, name, t)
        end
    end
    return
end

function PSI._update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::PSI.VariableValueAttributes{U},
    ::Type{PSY.HybridSystem},
    model::PSI.DecisionModel,
    state::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {
    T <: Union{JuMP.VariableRef, Float64},
    U <: ISOPT.AuxVarKey{V, PSY.HybridSystem},
} where {V <: Union{CyclingDischargeUsage, CyclingChargeUsage}}
    current_time = PSI.get_current_time(model)
    state_values = PSI.get_dataset_values(state, PSI.get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    final_time = time[end]
    model_resolution = PSI.get_resolution(model)
    state_data = PSI.get_dataset(state, PSI.get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = PSI.get_num_rows(state_data)

    if model_resolution < state_data.resolution
        t_step = 1
    else
        t_step = model_resolution ÷ state_data.resolution
    end
    state_data_index = PSI.find_timestamp_index(state_timestamps, current_time)
    # sim_timestamps = range(current_time; step=model_resolution, length=final_time)
    for name in component_names
        state_value = 0.0
        timestamp_range =
            state_data_index:min(max_state_index, state_data_index + final_time - 1)
        for t in timestamp_range
            #=
            @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
            if state_timestamps[timestamp_ix] <= sim_timestamps[t]
                state_data_index = timestamp_ix
            end
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            =#
            state_value_ = state_values[name, t]
            if !isfinite(state_value_)
                error(
                    "The value for the system state used in $(encode_key_as_string(get_attribute_key(attributes))) is not a finite value $(state_value) \
                    This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                    Consider reviewing your models' horizon and interval definitions",
                )
            end
            state_value += state_value_
        end
        _set_param_value_hss!(parameter_array, state_value, name, final_time)
    end
    return
end

# Container for Total Reserve #

function _set_param_value_hss!(
    param::AbstractArray,
    value::Float64,
    name::String,
    service_name::String,
    t::Int,
)
    param[name, service_name, t] = value
    return
end

function _set_param_value_hss!(param::AbstractArray, value::Float64, name::String, t::Int)
    PSI.fix_parameter_value(param[name, t], value)
    return
end

function PSI._add_parameters!(
    container::PSI.OptimizationContainer,
    ::T,
    key::PSI.VariableKey{TotalReserve, D},
    model::PSI.DeviceModel{D, W},
    devices::V,
) where {
    T <: PSI.FixValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: PSI.AbstractDeviceFormulation,
} where {D <: PSY.HybridSystem}
    var = PSI.get_variable(container, TotalReserve(), D)
    device_names, service_names, time_steps = axes(var)
    parameter_container = PSI.add_param_container!(
        container,
        T(),
        D,
        key,
        device_names,
        service_names,
        time_steps;
        meta = "$TotalReserve",
    )
    jump_model = PSI.get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        inital_parameter_value = 0.0
        for t in time_steps, service_name in service_names
            PSI.set_multiplier!(parameter_container, 1.0, name, service_name, t)
            PSI.set_parameter!(
                parameter_container,
                jump_model,
                inital_parameter_value,
                name,
                service_name,
                t,
            )
        end
    end
    return
end

function PSI._fix_parameter_value!(
    container::PSI.OptimizationContainer,
    parameter_array::JuMP.Containers.DenseAxisArray{Float64, 3},
    parameter_attributes::PSI.VariableValueAttributes{
        PowerSimulations.VariableKey{TotalReserve, PSY.HybridSystem},
    },
)
    affected_variable_keys = parameter_attributes.affected_keys
    @assert !isempty(affected_variable_keys)
    for var_key in affected_variable_keys
        variable = PSI.get_variable(container, var_key)
        component_names, services_names, time = axes(parameter_array)
        for t in time, s_name in services_names, name in component_names
            JuMP.fix(
                variable[name, s_name, t],
                parameter_array[name, s_name, t];
                force = true,
            )
        end
    end
    return
end

###################################################################
################### Cycling Battery Parameters ####################
###################################################################

function PSI._add_parameters!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    devices::V,
    model::PSI.DeviceModel{D, W},
) where {
    T <: Union{CyclingDischargeLimitParameter, CyclingChargeLimitParameter},
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    #@debug "adding" T D U _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    names = [PSY.get_name(device) for device in devices]
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    mult = fraction_of_hour * length(time_steps) / HOURS_IN_DAY
    if T <: CyclingDischargeLimitParameter
        key = PSI.AuxVarKey{CyclingDischargeUsage, PSY.HybridSystem}("")
    else
        key = PSI.AuxVarKey{CyclingChargeUsage, PSY.HybridSystem}("")
    end
    parameter_container =
        PSI.add_param_container!(container, T(), D, key, names, [time_steps[end]])
    jump_model = PSI.get_jump_model(container)

    for d in devices
        name = PSY.get_name(d)
        PSI.set_multiplier!(parameter_container, 1.0, name, time_steps[end])
        PSI.set_parameter!(
            parameter_container,
            jump_model,
            mult * PSI.get_initial_parameter_value(T(), d, W()),
            name,
            time_steps[end],
        )
    end
    return
end
