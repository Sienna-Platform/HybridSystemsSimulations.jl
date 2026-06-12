function PSI.calculate_aux_variable_value!(
    container::PSI.OptimizationContainer,
    ::PSI.AuxVarKey{CyclingChargeUsage, T},
    system::PSY.System,
) where {T <: PSY.HybridSystem}
    charge_var = PSI.get_variable(container, BatteryCharge(), T)
    device_names = axes(charge_var)[1]
    # Leave the other stuff the same #
    # for name in device_names
    # d = PSY.get_component(T, sys, name)
    # The same stuff
    # devices_hybrids = PSI.get_available_components(T, system)
    # devices = [d for d in devices_hybrids if PSY.get_storage(d) !== nothing]
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    # charge_var = PSI.get_variable(container, BatteryCharge(), T)
    aux_variable_container = PSI.get_aux_variable(container, CyclingChargeUsage(), T)
    for name in device_names
        # name = PSY.get_name(d)
        d = PSY.get_component(T, system, name)
        storage = PSY.get_storage(d)
        efficiency = PSY.get_efficiency(storage)
        for t in time_steps
            if !PSY.has_service(d, PSY.VariableReserve)
                aux_variable_container[name, t] =
                    efficiency.in * fraction_of_hour * PSI.jump_value(charge_var[name, t])
            else
                ch_served_reg_up =
                    PSI.get_expression(container, ChargeServedReserveUpExpression(), T)
                ch_served_reg_dn =
                    PSI.get_expression(container, ChargeServedReserveDownExpression(), T)
                aux_variable_container[name, t] =
                    efficiency.in *
                    fraction_of_hour *
                    (
                        PSI.jump_value(charge_var[name, t]) +
                        PSI.jump_value(ch_served_reg_dn[name, t]) -
                        PSI.jump_value(ch_served_reg_up[name, t])
                    )
            end
        end
    end

    return
end

function PSI.calculate_aux_variable_value!(
    container::PSI.OptimizationContainer,
    ::PSI.AuxVarKey{CyclingDischargeUsage, T},
    system::PSY.System,
) where {T <: PSY.HybridSystem}
    discharge_var = PSI.get_variable(container, BatteryDischarge(), T)
    device_names = axes(discharge_var)[1]
    # Leave the other stuff the same #
    # for name in device_names
    # d = PSY.get_component(T, sys, name)
    # The same stuff
    # devices_hybrids = PSI.get_available_components(T, system)
    # devices = [d for d in devices_hybrids if PSY.get_storage(d) !== nothing]
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    aux_variable_container = PSI.get_aux_variable(container, CyclingDischargeUsage(), T)
    for name in device_names
        # name = PSY.get_name(d)
        d = PSY.get_component(T, system, name)
        storage = PSY.get_storage(d)
        efficiency = PSY.get_efficiency(storage)
        for t in time_steps
            if !PSY.has_service(d, PSY.VariableReserve)
                aux_variable_container[name, t] =
                    (1.0 / efficiency.out) *
                    fraction_of_hour *
                    PSI.jump_value(discharge_var[name, t])
            else
                ds_served_reg_up =
                    PSI.get_expression(container, DischargeServedReserveUpExpression(), T)
                ds_served_reg_dn =
                    PSI.get_expression(container, DischargeServedReserveDownExpression(), T)
                aux_variable_container[name, t] =
                    (1.0 / efficiency.out) *
                    fraction_of_hour *
                    (
                        PSI.jump_value(discharge_var[name, t]) +
                        PSI.jump_value(ds_served_reg_up[name, t]) -
                        PSI.jump_value(ds_served_reg_dn[name, t])
                    )
            end
        end
    end

    return
end

function PSI.update_system_state!(
    state::PSI.DatasetContainer{PSI.InMemoryDataset},
    key::PSI.AuxVarKey{T, PSY.HybridSystem},
    decision_state::PSI.DatasetContainer{PSI.InMemoryDataset},
    simulation_time::Dates.DateTime,
) where {T <: Union{CyclingDischargeUsage, CyclingChargeUsage}}
    decision_dataset = PSI.get_dataset(decision_state, key)
    # Gets the timestamp of the value used for the update, which might not match exactly the
    # simulation time since the value might have not been updated yet

    ts = PSI.get_value_timestamp(decision_dataset, simulation_time)
    system_dataset = PSI.get_dataset(state, key)
    system_state_resolution = PSI.get_data_resolution(system_dataset)
    decision_state_resolution = PSI.get_data_resolution(decision_dataset)

    decision_state_value = PSI.get_dataset_value(decision_dataset, simulation_time)

    if ts == PSI.get_update_timestamp(system_dataset)
        # Uncomment for debugging
        #@warn "Skipped overwriting data with the same timestamp \\
        #       key: $(encode_key_as_string(key)), $(simulation_time), $ts"
        return
    end

    if PSI.get_update_timestamp(system_dataset) > ts
        error("Trying to update with past data a future state timestamp \\
            key: $(PSI.encode_key_as_string(key)), $(simulation_time), $ts")
    end

    # Writes the timestamp of the value used for the update
    PSI.set_update_timestamp!(system_dataset, ts)
    # Keep coordination between fields. System state is an array of size 1
    system_dataset.timestamps[1] = ts
    time_ratio = (decision_state_resolution / system_state_resolution)
    # Don't use set_dataset_values!(state, key, 1, decision_state_value).
    # For the time variables we need to grab the values to avoid mutation of the
    # dataframe row
    PSI.set_value!(system_dataset, values(decision_state_value) .* time_ratio, 1)
    # This value shouldn't be other than one and after one execution is no-op.
    PSI.set_last_recorded_row!(system_dataset, 1)
    return
end

function PSI.update_decision_state!(
    state::PSI.SimulationState,
    key::PSI.AuxVarKey{T, PSY.HybridSystem},
    store_data::JuMP.Containers.DenseAxisArray{Float64, 2},
    simulation_time::Dates.DateTime,
    model_params::PSI.ModelStoreParams,
) where {T <: Union{CyclingDischargeUsage, CyclingChargeUsage}}
    state_data = PSI.get_decision_state_data(state, key)
    column_names = PSI.get_column_names(key, state_data)[1]
    model_resolution = PSI.get_resolution(model_params)
    state_resolution = PSI.get_data_resolution(state_data)
    resolution_ratio = model_resolution ÷ state_resolution
    state_timestamps = state_data.timestamps
    IS.@assert_op resolution_ratio >= 1
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

    offset = resolution_ratio - 1
    result_time_index = axes(store_data)[2]
    PSI.set_update_timestamp!(state_data, simulation_time)
    for t in result_time_index
        state_range = state_data_index:(state_data_index + offset)
        for name in column_names, i in state_range
            # TODO: We could also interpolate here
            state_data.values[name, i] = max(0.0, store_data[name, t] / resolution_ratio)
        end
        PSI.set_last_recorded_row!(state_data, state_range[end])
        state_data_index += resolution_ratio
    end
    return
end
