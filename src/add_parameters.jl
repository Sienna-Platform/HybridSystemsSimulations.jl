###################################################################
################### Decision Model Parameters #####################
###################################################################

function _add_time_series_parameters(
    container::PSI.OptimizationContainer,
    ts_name::String,
    param,
    devices::Vector{PSY.HybridSystem},
)
    ts_name
    ts_type = PSI.get_default_time_series_type(container)
    time_steps = PSI.get_time_steps(container)

    device_names = String[]
    initial_values = Dict{String, AbstractArray}()
    for device in devices
        push!(device_names, PSY.get_name(device))
        ts_uuid = string(IS.get_time_series_uuid(ts_type, device, ts_name))
        if !(ts_uuid in keys(initial_values))
            initial_values[ts_uuid] =
                PSI.get_time_series_initial_values!(container, ts_type, device, ts_name)
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
        multiplier = PSY.get_max_active_power(device.renewable_unit)
        for step in time_steps
            PSI.set_multiplier!(param_container, multiplier, name, step)
        end
        PSI.add_component_name!(
            PSI.get_attributes(param_container),
            name,
            string(IS.get_time_series_uuid(ts_type, device, ts_name)),
        )
    end
    return
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
    ts_key::String,
    devices::Vector{PSY.HybridSystem},
    time_step_string::String,
    vars::Vector,
)
    time_steps = 1:PSY.get_ext(first(devices))[time_step_string]
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
            λ = PSY.get_ext(device)[ts_key]
            Bus_name = PSY.get_name(PSY.get_bus(device))
            price_value = λ[!, Bus_name]
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
    time_step_string::String,
    vars::Vector,
)
    time_steps = 1:PSY.get_ext(first(devices))[time_step_string]
    device_names = PSY.get_name.(devices)
    jump_model = PSI.get_jump_model(container)

    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
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
                ts_key_service = "$(ts_key)_$(service_name)"
                λ = PSY.get_ext(device)[ts_key_service]
                Bus_name = PSY.get_name(PSY.get_bus(device))
                price_value = λ[!, Bus_name]
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
    devices::Vector{PSY.HybridSystem},
    ts_name = "RenewableDispatch__max_active_power",
)
    _add_time_series_parameters(container, ts_name, param, devices)
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::ElectricLoadTimeSeries,
    devices::Vector{PSY.HybridSystem},
    ts_name = "PowerLoad__max_active_power",
)
    _add_time_series_parameters(container, ts_name, param, devices)
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
    ts_key = "λ_da_df"
    vars = [EnergyDABidOut, EnergyDABidIn]
    _add_price_time_series_parameters(container, param, ts_key, devices, "horizon_DA", vars)
    return
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::RealTimeEnergyPrice,
    devices::Vector{PSY.HybridSystem},
)
    ts_key = "λ_rt_df"
    vars = [EnergyDABidOut, EnergyDABidIn, EnergyRTBidOut, EnergyRTBidIn]
    _add_price_time_series_parameters(container, param, ts_key, devices, "horizon_RT", vars)
    return
end

function add_time_series_parameters!(
    container::PSI.OptimizationContainer,
    param::AncillaryServicePrice,
    devices::Vector{PSY.HybridSystem},
)
    ts_key = "λ"
    vars = [BidReserveVariableOut, BidReserveVariableIn]
    _add_price_time_series_parameters(container, param, ts_key, devices, "horizon_DA", vars)
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
    resolution = PSI.get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / PSI.SECONDS_IN_HOUR
    for component in components
        ext = PSY.get_ext(component)
        horizon = ext["horizon_DA"]
        bus_name = PSY.get_name(PSY.get_bus(component))
        ix = PSI.find_timestamp_index(ext["λ_da_df"][!, "DateTime"], initial_forecast_time)
        λ = ext["λ_da_df"][!, bus_name][ix:(ix + horizon - 1)]
        name = PSY.get_name(component)
        for (t, value) in enumerate(λ)
            # Since the DA variables are hourly, this will revert the dt multiplication
            PSI._set_param_value!(parameter_array, value * 1.0 * 100.0, name, t)
            PSI.update_variable_cost!(
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
function _update_parameter_values!(
    model::PSI.DecisionModel{T},
    key::PSI.ParameterKey{RealTimeEnergyPrice, PSY.HybridSystem},
) where {T <: HybridDecisionProblem}
    initial_forecast_time = PSI.get_current_time(model)
    container = PSI.get_optimization_container(model)
    resolution = PSI.get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / PSI.SECONDS_IN_HOUR
    parameter_array = PSI.get_parameter_array(container, key)
    attributes = PSI.get_parameter_attributes(container, key)
    components = PSI.get_available_components(PSY.HybridSystem, PSI.get_system(model))
    variable =
        PSI.get_variable(container, PSI.get_variable_type(attributes)(), PSY.HybridSystem)
    parameter_multiplier = PSI.get_parameter_multiplier_array(container, key)
    for component in components
        ext = PSY.get_ext(component)
        tmap = ext["tmap"]
        horizon = ext["horizon_RT"]
        bus_name = PSY.get_name(PSY.get_bus(component))
        ix = PSI.find_timestamp_index(ext["λ_rt_df"][!, "DateTime"], initial_forecast_time)
        λ = ext["λ_rt_df"][!, bus_name][ix:(ix + horizon - 1)]
        name = PSY.get_name(component)
        for (t, value) in enumerate(λ)
            mul_ = parameter_multiplier[name, t] * 100.0
            _val = value * dt * mul_
            PSI._set_param_value!(parameter_array, _val, name, t)
            if PSI.get_variable_type(attributes) ∈ (EnergyDABidOut, EnergyDABidIn)
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
