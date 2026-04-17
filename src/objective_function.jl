############### Storage costs, HybridSystem #######################
PSI.objective_function_multiplier(
    ::Union{BatteryCharge, BatteryDischarge},
    ::AbstractHybridFormulation,
) = PSI.OBJECTIVE_FUNCTION_POSITIVE

PSI.objective_function_multiplier(
    ::Union{BatteryEnergySurplusVariable, BatteryEnergySurplusVariable},
    ::AbstractHybridFormulation,
) = PSI.OBJECTIVE_FUNCTION_POSITIVE

PSI.objective_function_multiplier(
    ::BatteryRegularizationVariable,
    ::AbstractHybridFormulation,
) = PSI.OBJECTIVE_FUNCTION_POSITIVE

PSI.proportional_cost(
    cost::PSY.OperationalCost,
    ::BatteryDischarge,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_proportional_term(PSY.get_vom_cost(PSY.get_discharge_variable_cost(cost)))

PSI.proportional_cost(
    cost::PSY.OperationalCost,
    ::BatteryCharge,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_proportional_term(PSY.get_vom_cost(PSY.get_charge_variable_cost(cost)))

PSI.proportional_cost(
    cost::PSY.StorageCost,
    ::BatteryEnergySurplusVariable,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_energy_surplus_cost(cost)

PSI.proportional_cost(
    cost::PSY.StorageCost,
    ::BatteryEnergyShortageVariable,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_energy_shortage_cost(cost)

PSI.proportional_cost(
    cost::PSY.StorageCost,
    ::ChargeRegularizationVariable,
    ::PSY.HybridSystem,
    W::AbstractHybridFormulationWithReserves,
) = REG_COST #PSY.get_charge_variable_cost(cost) # PSY.charge_variable_cost(cost) #REG_COST

PSI.proportional_cost(
    cost::PSY.StorageCost,
    ::DischargeRegularizationVariable,
    ::PSY.HybridSystem,
    W::AbstractHybridFormulationWithReserves,
) = REG_COST #PSY.get_discharge_variable_cost(cost) #PSY.discharge_variable_cost(cost) #  #REG_COST

function PSI.proportional_cost(
    cost::PSY.StorageCost,
    ::BatteryRegularizationVariable,
    ::PSY.HybridSystem,
    ::AbstractHybridFormulation,
)
    return REG_COST #max(REG_COST, PSY.get_variable(cost).cost * REG_COST)
end

# HSA 11-6-2024 ===
# function PSI.proportional_cost(
#     cost::PSY.StorageCost,
#     ::ChargeRegularizationVariable,
#     ::PSY.HybridSystem,
#     ::AbstractHybridFormulation,
# )
#     return max(REG_COST, PSY.charge_variable_cost(cost) * REG_COST)
# end

# function PSI.proportional_cost(
#     cost::PSY.StorageCost,
#     ::DischargeRegularizationVariable,
#     ::PSY.HybridSystem,
#     ::AbstractHybridFormulation,
# )
#     return max(REG_COST, PSY.discharge_variable_cost(cost) * REG_COST)
# end
# HSA 11-6-2024 ===

function PSI.add_proportional_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    ::W,
) where {
    T <: Union{BatteryCharge, BatteryDischarge},
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    multiplier = PSI.objective_function_multiplier(T(), W())
    for d in devices
        op_cost_data = PSY.get_operation_cost(PSY.get_storage(d))
        isnothing(op_cost_data) && continue
        cost_term = PSI.proportional_cost(op_cost_data, T(), d, W())
        iszero(cost_term) && continue
        for t in PSI.get_time_steps(container)
            PSI._add_proportional_term!(container, T(), d, cost_term * multiplier, t)
        end
    end
    return
end

function PSI.add_proportional_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    formulation::W,
) where {
    T <: Union{BatteryEnergyShortageVariable, BatteryEnergySurplusVariable},
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    variable = PSI.get_variable(container, T(), D)
    for d in devices
        name = PSY.get_name(d)
        storage = PSY.get_storage(d)
        op_cost_data = PSY.get_operation_cost(storage)
        cost_term = PSI.proportional_cost(op_cost_data, T(), d, formulation)
        PSI.add_to_objective_invariant_expression!(container, variable[name] * cost_term)
    end
end

function PSI.add_proportional_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    ::W,
) where {
    T <: BatteryRegularizationVariable,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    multiplier = PSI.objective_function_multiplier(T(), W())
    for d in devices
        op_cost_data = PSY.get_operation_cost(PSY.get_storage(d))
        isnothing(op_cost_data) && continue
        cost_term = PSI.proportional_cost(op_cost_data, T(), d, W())
        # value_curve = PSY.get_value_curve(cost_term)
        # proportional_term = PSY.get_proportional_term(value_curve)

        # println("===============================================")
        # println(" ")
        # println("Proportional term: $proportional_term")
        # println(" ")
        # println("===============================================")
        iszero(cost_term) && continue
        for t in PSI.get_time_steps(container)
            PSI._add_proportional_term!(container, T(), d, cost_term * multiplier, t)
            #PSI._add_proportional_term!(container, T(), d, proportional_term * multiplier, t)
        end
    end
    return
end

############### Thermal costs, HybridSystem #######################

PSI.objective_function_multiplier(
    ::Union{ThermalPower, PSI.OnVariable},
    ::AbstractHybridFormulation,
) = PSI.OBJECTIVE_FUNCTION_POSITIVE

PSI.objective_function_multiplier(
    ::Union{ThermalPower, PSI.OnVariable},
    ::Union{MerchantModelEnergyOnly, MerchantModelWithReserves},
) = PSI.OBJECTIVE_FUNCTION_NEGATIVE

PSI.proportional_cost(
    cost::PSY.OperationalCost,
    ::PSI.OnVariable,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_fixed(cost)

PSI.variable_cost(
    cost::PSY.OperationalCost,
    ::ThermalPower,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_variable(cost)

PSI.uses_compact_power(::PSY.HybridSystem, ::AbstractHybridFormulation) = false

PSI.sos_status(::PSY.HybridSystem, ::AbstractHybridFormulation) =
    PSI.SOSStatusVariable.VARIABLE

PSI.sos_status(::PSY.ThermalGen, ::AbstractHybridFormulation) =
    PSI.SOSStatusVariable.VARIABLE

function PSI.add_proportional_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    ::W,
) where {
    T <: PSI.OnVariable,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    multiplier = PSI.objective_function_multiplier(T(), W())
    for d in devices
        thermal_component = PSY.get_thermal_unit(d)
        isnothing(thermal_component) && continue
        op_cost_data = PSY.get_operation_cost(thermal_component)
        isnothing(op_cost_data) && continue
        cost_term = PSI.proportional_cost(op_cost_data, T(), d, W())
        iszero(cost_term) && continue
        for t in PSI.get_time_steps(container)
            PSI._add_proportional_term!(container, T(), d, cost_term * multiplier, t)
        end
    end
    return
end

function PSI.add_variable_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    ::W,
) where {
    T <: ThermalPower,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    for d in devices
        thermal_component = PSY.get_thermal_unit(d)
        op_cost_data = PSY.get_operation_cost(thermal_component)
        variable_cost_data = PSI.variable_cost(op_cost_data, T(), d, W())
        PSI._add_variable_cost_to_objective!(container, T(), d, variable_cost_data, W())
    end
    return
end

function PSI.get_fuel_cost_value(
    container::PSI.OptimizationContainer,
    component::PSY.HybridSystem,
    t::Int,
    is_time_variant::Val{false},
)
    thermal_component = PSY.get_thermal_unit(component)
    return PSI.get_fuel_cost_value(container, thermal_component, t, is_time_variant)
end

_extract_first_numeric_value(value::Number) = Float64(value)
_extract_first_numeric_value(value::AbstractArray) = Float64(first(value))
_extract_first_numeric_value(value) =
    if hasproperty(value, :values)
        Float64(first(getproperty(value, :values)))
    else
        throw(
        ArgumentError(
            "Unable to extract scalar fuel cost from $(typeof(value)); expected Number or array-like values.",
        ),
    )
    end

_time_step_datetime(container::PSI.OptimizationContainer, t::Int) =
    PSI.get_initial_time(container) + (t - 1) * PSI.get_resolution(container)

function _first_piecewise_slope(variable_cost)
    value_curve = PSY.get_value_curve(variable_cost)
    cost_component = PSY.get_function_data(value_curve)
    x_coords = PSY.get_x_coords(cost_component)
    y_coords = PSY.get_y_coords(cost_component)
    if length(x_coords) == length(y_coords) + 1
        # Piecewise-incremental format stores segment slopes directly in y-coordinates.
        return first(y_coords)
    elseif length(x_coords) == length(y_coords) && length(x_coords) >= 2
        return (y_coords[2] - y_coords[1]) / (x_coords[2] - x_coords[1])
    end
    throw(
        ArgumentError(
            "Unsupported piecewise curve data shape for $(typeof(cost_component)): " *
            "length(x_coords)=$(length(x_coords)), length(y_coords)=$(length(y_coords)).",
        ),
    )
end

function get_thermal_fixed_cost_per_hour(component::PSY.HybridSystem)
    thermal_component = PSY.get_thermal_unit(component)
    isnothing(thermal_component) && return 0.0
    return PSY.get_fixed(PSY.get_operation_cost(thermal_component))
end

function get_thermal_marginal_cost_per_system_unit(
    container::PSI.OptimizationContainer,
    component::PSY.HybridSystem,
    t::Int,
)
    thermal_component = PSY.get_thermal_unit(component)
    isnothing(thermal_component) && return 0.0
    op_cost = PSY.get_operation_cost(thermal_component)
    variable_cost = PSY.get_variable(op_cost)
    base_power = PSI.get_base_power(container)
    device_base_power = PSY.get_base_power(thermal_component)

    if variable_cost isa PSY.CostCurve{PSY.LinearCurve}
        value_curve = PSY.get_value_curve(variable_cost)
        cost_component = PSY.get_function_data(value_curve)
        proportional_term = PSY.get_proportional_term(cost_component)
        return PSI.get_proportional_cost_per_system_unit(
            proportional_term,
            PSY.get_power_units(variable_cost),
            base_power,
            device_base_power,
        )
    elseif variable_cost isa Union{
        PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
        PSY.CostCurve{PSY.PiecewisePointCurve},
    }
        slope = _first_piecewise_slope(variable_cost)
        return PSI.get_proportional_cost_per_system_unit(
            slope,
            PSY.get_power_units(variable_cost),
            base_power,
            device_base_power,
        )
    elseif variable_cost isa PSY.FuelCurve{PSY.LinearCurve}
        value_curve = PSY.get_value_curve(variable_cost)
        cost_component = PSY.get_function_data(value_curve)
        proportional_term = PSY.get_proportional_term(cost_component)
        fuel_curve_per_unit = PSI.get_proportional_cost_per_system_unit(
            proportional_term,
            PSY.get_power_units(variable_cost),
            base_power,
            device_base_power,
        )
        fuel_cost_data = PSY.get_fuel_cost(variable_cost)
        fuel_cost_value = if PSI.is_time_variant(fuel_cost_data)
            timestamp = _time_step_datetime(container, t)
            PSY.get_fuel_cost(thermal_component; start_time = timestamp, len = 1)
        else
            PSY.get_fuel_cost(thermal_component)
        end
        return fuel_curve_per_unit * _extract_first_numeric_value(fuel_cost_value)
    elseif variable_cost isa Union{
        PSY.FuelCurve{PSY.PiecewiseIncrementalCurve},
        PSY.FuelCurve{PSY.PiecewisePointCurve},
    }
        slope = _first_piecewise_slope(variable_cost)
        fuel_curve_per_unit = PSI.get_proportional_cost_per_system_unit(
            slope,
            PSY.get_power_units(variable_cost),
            base_power,
            device_base_power,
        )
        fuel_cost_data = PSY.get_fuel_cost(variable_cost)
        fuel_cost_value = if PSI.is_time_variant(fuel_cost_data)
            timestamp = _time_step_datetime(container, t)
            PSY.get_fuel_cost(thermal_component; start_time = timestamp, len = 1)
        else
            PSY.get_fuel_cost(thermal_component)
        end
        return fuel_curve_per_unit * _extract_first_numeric_value(fuel_cost_value)
    end

    throw(
        ArgumentError(
            "Unsupported thermal variable cost type $(typeof(variable_cost)) for merchant HybridSystem models. Use linear CostCurve or linear FuelCurve.",
        ),
    )
end

############### Renewable costs, HybridSystem #######################

PSI.objective_function_multiplier(::RenewablePower, ::AbstractHybridFormulation) =
    PSI.OBJECTIVE_FUNCTION_NEGATIVE

PSI.objective_function_multiplier(
    ::RenewablePower,
    ::Union{MerchantModelEnergyOnly, MerchantModelWithReserves},
) = PSI.OBJECTIVE_FUNCTION_POSITIVE

PSI.variable_cost(
    cost::PSY.OperationalCost,
    ::RenewablePower,
    ::PSY.HybridSystem,
    U::AbstractHybridFormulation,
) = PSY.get_variable(cost)

function PSI.add_variable_cost!(
    container::PSI.OptimizationContainer,
    ::T,
    devices::U,
    ::W,
) where {
    T <: RenewablePower,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    for d in devices
        op_cost_data = PSY.get_operation_cost(PSY.get_renewable_unit(d))
        PSI._add_variable_cost_to_objective!(container, T(), d, op_cost_data, W())
    end
    return
end

############### Storage costs, HybridSystem #######################

############### Objective Function, HybridSystem #######################

function PSI.objective_function!(
    container::PSI.OptimizationContainer,
    devices::U,
    model::PSI.DeviceModel{D, W},
    ::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    # Filter Devices
    _hybrids_with_thermal = [d for d in devices if PSY.get_thermal_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in devices if PSY.get_storage(d) !== nothing]
    _hybrids_with_renewable = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]

    # Add Storage Cost
    if !isempty(_hybrids_with_storage)
        PSI.add_proportional_cost!(container, BatteryCharge(), _hybrids_with_storage, W())
        PSI.add_proportional_cost!(
            container,
            BatteryDischarge(),
            _hybrids_with_storage,
            W(),
        )
        if PSI.get_attribute(model, "energy_target")
            PSI.add_proportional_cost!(
                container,
                BatteryEnergySurplusVariable(),
                _hybrids_with_storage,
                W(),
            )
            PSI.add_proportional_cost!(
                container,
                BatteryEnergyShortageVariable(),
                _hybrids_with_storage,
                W(),
            )
        end
        if PSI.get_attribute(model, "regularization")
            PSI.add_proportional_cost!(
                container,
                ChargeRegularizationVariable(),
                _hybrids_with_storage,
                W(),
            )
            PSI.add_proportional_cost!(
                container,
                DischargeRegularizationVariable(),
                _hybrids_with_storage,
                W(),
            )
        end
    end

    # Add Thermal Cost
    if !isempty(_hybrids_with_thermal)
        PSI.add_variable_cost!(container, ThermalPower(), _hybrids_with_thermal, W())
        PSI.add_proportional_cost!(container, PSI.OnVariable(), _hybrids_with_thermal, W())
    end

    # Add Renewable Cost
    if !isempty(_hybrids_with_renewable)
        PSI.add_variable_cost!(container, RenewablePower(), _hybrids_with_renewable, W())
    end
    return
end
