"""
    CyclingChargeLimitFeedforward

Feedforward that enforces a cumulative charging cycle limit on the hybrid's storage
over the simulation. The constraint is ``\\eta_{\\text{ch}} \\Delta t \\sum_t (p_{\\text{ch},t} + s^{\\text{down}}_{\\text{reg},t} - s^{\\text{up}}_{\\text{reg},t}) \\leq \\text{limit}``,
where ``s^{\\text{up}}_{\\text{reg},t}`` and ``s^{\\text{down}}_{\\text{reg},t}`` denote served reserve (up/down). The limit is from [`CyclingChargeLimitParameter`](@ref) in recurrent solves or
``C_{\\text{horizon}} \\times E_{\\max,\\text{st}}`` otherwise. Use with PowerSimulations' `add_feedforward!` in a
[`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) for
[`HybridDispatchWithReserves`](@ref) or [`HybridEnergyOnlyDispatch`](@ref).
"""
struct CyclingChargeLimitFeedforward <: PSI.AbstractAffectFeedforward
    optimization_container_key::PSI.OptimizationContainerKey
    affected_values::Vector{<:PSI.OptimizationContainerKey}
    penalty_cost::Float64
    function CyclingChargeLimitFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        penalty_cost::Float64,
        meta = ISOPT.CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{PSI.ParameterKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: PSI.ParameterType
                values_vector[ix] =
                    PSI.get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "CyclingChargeLimitFeedforward is only compatible with VariableType or ParamterType affected values",
                )
            end
        end
        new(
            PSI.get_optimization_container_key(T(), component_type, meta),
            values_vector,
            penalty_cost,
        )
    end
end

PSI.get_default_parameter_type(::CyclingChargeLimitFeedforward, _) =
    CyclingChargeLimitParameter
PSI.get_optimization_container_key(ff::CyclingChargeLimitFeedforward) =
    ff.optimization_container_key

"""
    CyclingDischargeLimitFeedforward

Feedforward that enforces a cumulative discharging cycle limit on the hybrid's storage:
``(1/\\eta_{\\text{ds}}) \\Delta t \\sum_t (p_{\\text{ds},t} + s^{\\text{up}}_{\\text{reg},t} - s^{\\text{down}}_{\\text{reg},t}) \\leq \\text{limit}``,
where ``s^{\\text{up}}_{\\text{reg},t}`` and ``s^{\\text{down}}_{\\text{reg},t}`` denote served reserve (up/down). The limit comes from
[`CyclingDischargeLimitParameter`](@ref) in recurrent runs. See
[`CyclingChargeLimitFeedforward`](@ref) for usage pattern.
"""
struct CyclingDischargeLimitFeedforward <: PSI.AbstractAffectFeedforward
    optimization_container_key::PSI.OptimizationContainerKey
    affected_values::Vector{<:PSI.OptimizationContainerKey}
    penalty_cost::Float64
    function CyclingDischargeLimitFeedforward(;
        component_type::Type{<:PSY.Component},
        source::Type{T},
        affected_values::Vector{DataType},
        penalty_cost::Float64,
        meta = ISOPT.CONTAINER_KEY_EMPTY_META,
    ) where {T}
        values_vector = Vector{PSI.ParameterKey}(undef, length(affected_values))
        for (ix, v) in enumerate(affected_values)
            if v <: PSI.ParameterType
                values_vector[ix] =
                    PSI.get_optimization_container_key(v(), component_type, meta)
            else
                error(
                    "CyclingDischargeLimitFeedforward is only compatible with VariableType or ParamterType affected values",
                )
            end
        end
        new(
            PSI.get_optimization_container_key(T(), component_type, meta),
            values_vector,
            penalty_cost,
        )
    end
end

PSI.get_default_parameter_type(::CyclingDischargeLimitFeedforward, _) =
    CyclingDischargeLimitParameter
PSI.get_optimization_container_key(ff::CyclingDischargeLimitFeedforward) =
    ff.optimization_container_key

function PSI.add_feedforward_arguments!(
    container::PSI.OptimizationContainer,
    model::PSI.DeviceModel,
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
) where {D <: PSY.HybridSystem}
    for ff in PSI.get_feedforwards(model)
        PSI._add_feedforward_arguments!(container, model, devices, ff)
    end
    return
end

# function _add_cycling_feedfo

function PSI._add_feedforward_arguments!(
    container::PSI.OptimizationContainer,
    device_model::PSI.DeviceModel,
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::U,
) where {
    D <: PSY.HybridSystem,
    U <: Union{CyclingChargeLimitFeedforward, CyclingDischargeLimitFeedforward},
}
    if PSI.get_attribute(device_model, "cycling")
        throw(
            IS.ConflictingInputsError("Cycling Attribute not allowed with $U Feedforwards"),
        )
    end
    parameter_type = PSI.get_default_parameter_type(ff, D)
    PSI._add_parameters!(container, parameter_type, devices, device_model)
    return
end

function PSI._add_feedforward_arguments!(
    container::PSI.OptimizationContainer,
    model::PSI.DeviceModel,
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::PSI.AbstractAffectFeedforward,
) where {D <: PSY.HybridSystem}
    parameter_type = PSI.get_default_parameter_type(ff, D)
    PSI.add_parameters!(container, parameter_type, ff, model, devices)
    return
end

function PSI.add_feedforward_constraints!(
    container::PSI.OptimizationContainer,
    model::PSI.DeviceModel,
    devices::Vector{V},
) where {V <: PSY.HybridSystem}
    for ff in PSI.get_feedforwards(model)
        PSI.add_feedforward_constraints!(container, model, devices, ff)
    end
    return
end

function PSI.add_feedforward_constraints!(
    container::PSI.OptimizationContainer,
    device_model::PSI.DeviceModel,
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::CyclingChargeLimitFeedforward,
) where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    ch_served_reg_up = PSI.get_expression(container, ChargeServedReserveUpExpression(), D)
    ch_served_reg_dn = PSI.get_expression(container, ChargeServedReserveDownExpression(), D)
    T = FeedForwardCyclingChargeConstraint
    con_cycling_ch = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        E_max =
            PSY.get_storage_level_limits(storage).max * PSY.get_storage_capacity(storage)
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingChargeLimitParameter(), D)[
                    ci_name,
                    time_steps[end],
                ]
            con_cycling_ch[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                efficiency.in *
                fraction_of_hour *
                sum(
                    charge_var[ci_name, :] + ch_served_reg_dn[ci_name, :] -
                    ch_served_reg_up[ci_name, :],
                ) <= param_value
            )
        else
            E_max = PSY.get_storage_level_limits(storage).max
            cycles_per_day = PSY.get_cycle_limits(storage)
            cycles_in_horizon =
                cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
            con_cycling_ch[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                efficiency.in *
                fraction_of_hour *
                sum(
                    charge_var[ci_name, :] + ch_served_reg_dn[ci_name, :] -
                    ch_served_reg_up[ci_name, :],
                ) <= cycles_in_horizon * E_max
            )
        end
    end
    return
end

function PSI.add_feedforward_constraints!(
    container::PSI.OptimizationContainer,
    device_model::PSI.DeviceModel{D, HybridEnergyOnlyDispatch},
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::CyclingChargeLimitFeedforward,
) where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    T = FeedForwardCyclingChargeConstraint
    con_cycling_ch = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        E_max = PSY.get_storage_level_limits(storage).max
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingChargeLimitParameter(), D)[
                    ci_name,
                    time_steps[end],
                ]
            con_cycling_ch[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                efficiency.in * fraction_of_hour * sum(charge_var[ci_name, :]) <=
                param_value
            )
        else
            E_max = PSY.get_storage_level_limits(storage).max
            cycles_per_day = PSY.get_cycle_limits(storage)
            cycles_in_horizon =
                cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
            con_cycling_ch[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                efficiency.in * fraction_of_hour * sum(charge_var[ci_name, :]) <=
                cycles_in_horizon * E_max
            )
        end
    end
    return
end

function PSI.add_feedforward_constraints!(
    container::PSI.OptimizationContainer,
    device_model::PSI.DeviceModel,
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::CyclingDischargeLimitFeedforward,
) where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    ds_served_reg_up =
        PSI.get_expression(container, DischargeServedReserveUpExpression(), D)
    ds_served_reg_dn =
        PSI.get_expression(container, DischargeServedReserveDownExpression(), D)
    T = FeedForwardCyclingDischargeConstraint
    con_cycling_ds = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        E_max =
            PSY.get_storage_level_limits(storage).max * PSY.get_storage_capacity(storage)
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingDischargeLimitParameter(), D)[
                    ci_name,
                    time_steps[end],
                ]
            con_cycling_ds[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                (1.0 / efficiency.out) *
                fraction_of_hour *
                sum(
                    discharge_var[ci_name, :] + ds_served_reg_up[ci_name, :] -
                    ds_served_reg_dn[ci_name, :],
                ) <= param_value
            )
        else
            E_max = PSY.get_storage_level_limits(storage).max
            cycles_per_day = PSY.get_cycle_limits(storage)
            cycles_in_horizon =
                cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
            con_cycling_ds[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                (1.0 / efficiency.out) *
                fraction_of_hour *
                sum(
                    discharge_var[ci_name, :] + ds_served_reg_up[ci_name, :] -
                    ds_served_reg_dn[ci_name, :],
                ) <= cycles_in_horizon * E_max
            )
        end
    end
    return
end

function PSI.add_feedforward_constraints!(
    container::PSI.OptimizationContainer,
    device_model::PSI.DeviceModel{D, HybridEnergyOnlyDispatch},
    devices::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    ff::CyclingDischargeLimitFeedforward,
) where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    T = FeedForwardCyclingDischargeConstraint
    con_cycling_ds = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        E_max = PSY.get_storage_level_limits(storage).max
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingDischargeLimitParameter(), D)[
                    ci_name,
                    time_steps[end],
                ]
            con_cycling_ds[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                (1.0 / efficiency.out) *
                fraction_of_hour *
                sum(discharge_var[ci_name, :]) <= param_value
            )
        else
            E_max = PSY.get_storage_level_limits(storage).max
            cycles_per_day = PSY.get_cycle_limits(storage)
            cycles_in_horizon =
                cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
            con_cycling_ds[ci_name] = JuMP.@constraint(
                PSI.get_jump_model(container),
                (1.0 / efficiency.out) *
                fraction_of_hour *
                sum(discharge_var[ci_name, :]) <= cycles_in_horizon * E_max
            )
        end
    end
    return
end

function PSI.update_parameter_values!(
    model::PSI.DecisionModel,
    key::PSI.ParameterKey{T, U},
    input::PSI.DatasetContainer{PSI.InMemoryDataset},
) where {
    T <: Union{CyclingChargeLimitParameter, CyclingDischargeLimitParameter},
    U <: PSY.HybridSystem,
}
    # Enable again for detailed debugging
    # TimerOutputs.@timeit RUN_SIMULATION_TIMER "$T $U Parameter Update" begin
    optimization_container = PSI.get_optimization_container(model)
    # Note: Do not instantite a new key here because it might not match the param keys in the container
    # if the keys have strings in the meta fields
    parameter_array = PSI.get_parameter_array(optimization_container, key)
    parameter_attributes = PSI.get_parameter_attributes(optimization_container, key)
    current_time = PSI.get_current_time(model)
    state_values =
        PSI.get_dataset_values(input, PSI.get_attribute_key(parameter_attributes))
    component_names = axes(parameter_array)[1]
    model_resolution = PSI.get_resolution(optimization_container)
    state_data = PSI.get_dataset(input, PSI.get_attribute_key(parameter_attributes))
    state_timestamps = state_data.timestamps
    end_of_horizon_time =
        current_time +
        (PSI.get_time_steps(optimization_container)[end] - 1) * model_resolution
    state_data_index_start = PSI.find_timestamp_index(state_timestamps, current_time)
    state_data_index_end = PSI.find_timestamp_index(state_timestamps, end_of_horizon_time)
    for name in component_names
        param_value =
            max.(state_values[name, state_data_index_start:state_data_index_end], 1e-6)
        PSI.fix_parameter_value(parameter_array[name], sum(param_value))
    end

    IS.@record :execution PSI.ParameterUpdateEvent(
        T,
        U,
        parameter_attributes,
        PSI.get_current_timestamp(model),
        PSI.get_name(model),
    )
    return
end
