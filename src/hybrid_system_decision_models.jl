PSI.get_variable_binary(
    ::PSI.VariableType,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::BatteryStatus,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = true
PSI.get_variable_binary(
    ::PSI.OnVariable,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = true
PSI.get_variable_binary(
    ::PSI.ReservationVariable,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = true

# Defined to avoid ambiguity
PSI.get_variable_binary(
    ::PSI.ActivePowerOutVariable,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::PSI.ActivePowerInVariable,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::ThermalPower,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::RenewablePower,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::BatteryCharge,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::BatteryDischarge,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false
PSI.get_variable_binary(
    ::PSI.EnergyVariable,
    t::Type{PSY.HybridSystem},
    ::HybridDecisionProblem,
) = false

PSI.get_variable_binary(
    ::EnergyRTBidOut,
    ::Type{PSY.HybridSystem},
    ::AbstractHybridFormulation,
) = false

PSI.get_variable_binary(
    ::EnergyRTBidIn,
    ::Type{PSY.HybridSystem},
    ::AbstractHybridFormulation,
) = false

PSI.get_variable_binary(
    ::MerchantModelDualVariable,
    ::Type{PSY.HybridSystem},
    ::AbstractHybridFormulation,
) = false

PSI.get_variable_binary(
    ::MerchantModelComplementarySlackVariable,
    ::Type{PSY.HybridSystem},
    ::AbstractHybridFormulation,
) = false

# UBs and LowerBounds Decision Problem
PSI.get_variable_lower_bound(
    ::EnergyDABidOut,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyDABidOut,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyDABidIn,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyDABidIn,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyRTBidOut,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyRTBidOut,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyRTBidIn,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyRTBidIn,
    d::PSY.HybridSystem,
    ::HybridDecisionProblem,
) = PSY.get_output_active_power_limits(d).max

# UBs and LBs for Formulation
PSI.get_variable_lower_bound(
    ::EnergyDABidOut,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyDABidOut,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyDABidIn,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyDABidIn,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyRTBidOut,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyRTBidOut,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::EnergyRTBidIn,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = 0.0
PSI.get_variable_upper_bound(
    ::EnergyRTBidIn,
    d::PSY.HybridSystem,
    ::AbstractHybridFormulation,
) = PSY.get_output_active_power_limits(d).max

PSI.get_variable_lower_bound(
    ::MerchantModelDualVariable,
    ::Type{PSY.HybridSystem},
    ::AbstractHybridFormulation,
) = 0.0

function _get_row_val(df, row_name)
    return df[only(findall(==(row_name), df.ParamName)), :]["Value"]
end

###################################################################
############ Update Parameters for Simulation Stages  #############
###################################################################

function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.VariableKey{T, PSY.HybridSystem},
    store_data::PSI.DenseAxisArray{Float64, 2},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
) where {T <: Union{EnergyDABidOut, EnergyDABidIn}}
    @debug "updating decision state $simulation_time"
    state_data = PSI.get_decision_state_data(state, key)
    model_resolution = PSI.get_resolution(model_params) # var res: 1 hour
    model_resolution = Dates.Hour(1) #TODO: Find a ext hack
    state_resolution = PSI.get_data_resolution(state_data) # 5 min
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    PSI.IS.@assert_op resolution_ratio >= 1

    if simulation_time > PSI.get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .= range(
            simulation_time;
            step=state_resolution,
            length=PSI.get_num_rows(state_data),
        )
    else
        state_data_index = PSI.find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[2]
    PSI.set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in axes(state_data.values)[1], i in state_range
            # TODO: We could also interpolate here
            state_data.values[name, i] = store_data[name, t]
        end
        PSI.set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end

function PSI._update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::PSI.VariableValueAttributes{
        PSI.VariableKey{U, PSY.HybridSystem},
    },
    ::Type{<:PSY.HybridSystem},
    model::PSI.DecisionModel,
    state::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}, U <: Union{EnergyDABidOut, EnergyDABidIn}}
    current_time = PSI.get_current_time(model)
    state_values = PSI.get_dataset_values(state, PSI.get_attribute_key(attributes))
    component_names, time = axes(parameter_array)
    model_resolution = PSI.get_resolution(model)
    state_data = PSI.get_dataset(state, PSI.get_attribute_key(attributes))
    t_step = model_resolution ÷ state_data.resolution
    @assert t_step > 0
    state_timestamps = state_data.timestamps
    max_state_index = PSI.get_num_rows(state_data)
    state_data_index = PSI.find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time; step=model_resolution, length=time[end])
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
                    "The value for the system state used in $(PSI.encode_key_as_string(PSI.get_attribute_key(attributes))) is not a finite value $(state_value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            PSI._set_param_value!(parameter_array, state_value, name, t)
        end
    end
    return
end

function PSI._fix_parameter_value!(
    container::PSI.OptimizationContainer,
    parameter_array::PSI.JuMPFloatMatrix,
    parameter_attributes::PSI.VariableValueAttributes{
        PSI.VariableKey{U, PSY.HybridSystem},
    },
) where {U <: Union{EnergyDABidIn, EnergyDABidOut}}
    affected_variable_keys = parameter_attributes.affected_keys
    for var_key in affected_variable_keys
        variable = PSI.get_variable(container, var_key)
        component_name_var, time_var = axes(variable)
        component_names, time = axes(parameter_array)
        if time_var[end] < time[end]
            for t in time_var, name in component_names
                t_ = 1 + (t - 1) * time[end] ÷ time_var[end]
                JuMP.fix(variable[name, t], parameter_array[name, t_]; force=true)
            end
        elseif time_var[end] == time[end]
            for t in time_var, name in component_names
                JuMP.fix(variable[name, t], parameter_array[name, t]; force=true)
            end
        else
            error("invalid condition")
        end
    end
    return
end

### TotalReserve ###

function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.VariableKey{W, PSY.HybridSystem},
    store_data::PSI.DenseAxisArray{Float64, 3},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
) where {W <: Union{TotalReserve, SlackReserveDown, SlackReserveUp}}
    @assert all(isfinite.(store_data))
    state_data = PSI.get_decision_state_data(state, key)
    # column_Names
    device_names, service_names = PSI.get_column_names(key, state_data)
    model_resolution = PSI.get_resolution(model_params)
    state_resolution = PSI.get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    PSI.IS.@assert_op resolution_ratio >= 1

    if simulation_time > PSI.get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .= range(
            simulation_time;
            step=state_resolution,
            length=PSI.get_num_rows(state_data),
        )
    else
        state_data_index = PSI.find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[3]
    PSI.set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in device_names, service in service_names, i in state_range
            # TODO: We could also interpolate here
            state_data.values[name, service, i] = store_data[name, service, t]
        end
        PSI.set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end

function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.ParameterKey{PSI.FixValueParameter, PSY.HybridSystem},
    store_data::PSI.DenseAxisArray{Float64, 3},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
)
    # Not needed
    return
end

function PSI._update_parameter_values!(
    parameter_array::AbstractArray{T},
    attributes::PSI.VariableValueAttributes{
        PSI.VariableKey{TotalReserve, PSY.HybridSystem},
    },
    ::Type{<:PSY.HybridSystem},
    model::PSI.DecisionModel,
    state::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {T <: Union{JuMP.VariableRef, Float64}}
    current_time = PSI.get_current_time(model)
    state_values = PSI.get_dataset_values(state, PSI.get_attribute_key(attributes))
    component_names, service_names, time = axes(parameter_array)
    model_resolution = PSI.get_resolution(model)
    state_data = PSI.get_dataset(state, PSI.get_attribute_key(attributes))
    state_timestamps = state_data.timestamps
    max_state_index = PSI.get_num_rows(state_data)
    if model_resolution < state_data.resolution
        t_step = 1
    elseif model_resolution >= state_data.resolution
        t_step = model_resolution ÷ state_data.resolution
    else
        @assert false
    end
    state_data_index = PSI.find_timestamp_index(state_timestamps, current_time)
    sim_timestamps = range(current_time; step=model_resolution, length=time[end])
    for t in time
        timestamp_ix = min(max_state_index, state_data_index + t_step)
        @debug "parameter horizon is over the step" max_state_index > state_data_index + 1
        if state_timestamps[timestamp_ix] <= sim_timestamps[t]
            state_data_index = timestamp_ix
        end
        for name in component_names, service_name in service_names
            # Pass indices in this way since JuMP DenseAxisArray don't support view()
            state_value = state_values[name, service_name, state_data_index]
            if !isfinite(state_value)
                error(
                    "The value for the system state used in $(PSI.encode_key_as_string(PSI.get_attribute_key(attributes))) is not a finite value $(state_value) \
                     This is commonly caused by referencing a state value at a time when such decision hasn't been made. \
                     Consider reviewing your models' horizon and interval definitions",
                )
            end
            PSI._set_param_value!(parameter_array, state_value, name, service_name, t)
        end
    end
    return
end

#=
function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.VariableKey{TotalReserve, PSY.HybridSystem},
    store_data::PSI.DenseAxisArray{Float64, 3},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
)
    @debug "updating decision state $simulation_time"
    @show model_params
    state_data = PSI.get_decision_state_data(state, key)
    model_resolution = PSI.get_resolution(model_params) # var res: 1 hour
    model_resolution = Dates.Hour(1) #TODO: Find a ext hack
    state_resolution = PSI.get_data_resolution(state_data) # 5 min
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    PSI.IS.@assert_op resolution_ratio >= 1

    if simulation_time > PSI.get_end_of_step_timestamp(state_data)
        state_data_index = 1
        state_data.timestamps[:] .= range(
            simulation_time;
            step=state_resolution,
            length=PSI.get_num_rows(state_data),
        )
    else
        state_data_index = PSI.find_timestamp_index(state_timestamps, simulation_time)
    end

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[end]
    PSI.set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        @show state_range = state_data_index:(state_data_index + offset)
        for name in axes(state_data.values)[1], service in axes(state_data.values)[2], i in state_range
            # TODO: We could also interpolate here
            aux = store_data[name, service, t]
            state_data.values[name, service, i] = aux
        end
        PSI.set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end
=#

###################################################################
#################### Feedforward Functions  #######################
###################################################################

function PSI.add_feedforward_arguments!(
    container::PSI.OptimizationContainer,
    model::PSI.DeviceModel{V, <:AbstractHybridFormulation},
    devices::Vector{V},
) where {V <: PSY.HybridSystem}
    for ff in PSI.get_feedforwards(model)
        #@debug "arguments" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        PSI._add_feedforward_arguments!(container, model, devices, ff)
    end
    return
end
