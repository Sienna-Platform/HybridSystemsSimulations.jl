###################################################################
#################### Device Model Constraints #####################
###################################################################

############ Total Power Constraints, HybridSystem ################
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:PSI.PowerVariableLimitsConstraint},
    U::Type{<:Union{PSI.ActivePowerInVariable, PSI.ActivePowerOutVariable}},
    devices::IS.FlattenIteratorWrapper{V},
    model::PSI.DeviceModel{V, W},
    network_model::PSI.NetworkModel{X},
) where {V <: PSY.HybridSystem, W <: AbstractHybridFormulation, X <: PM.AbstractPowerModel}
    PSI.add_range_constraints!(container, T, U, devices, model, X)
    return
end

############ Output/Input Constraints, HybridSystem ################

# Status Out ON (Generation Operation)
function _add_constraints_statusout!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusOutOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerOutVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_out[ci_name, t] <= max_limit * varon[ci_name, t]
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusOutOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_statusout!(container, T, devices, W())
    return
end

# Status Out ON (Generation Operation) With Reserves
function _add_constraints_statusout_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusOutOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    res_out_up = PSI.get_expression(container, TotalReserveOutUpExpression(), D)
    res_out_down = PSI.get_expression(container, TotalReserveOutDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerOutVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_out[ci_name, t] + res_out_up[ci_name, t] <= max_limit * varon[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_out[ci_name, t] - res_out_down[ci_name, t] >= 0.0
        )
    end
    return
end

function _add_constraints_statusout_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusOutOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    res_out_up = PSI.get_expression(container, TotalReserveOutUpExpression(), D)
    res_out_down = PSI.get_expression(container, TotalReserveOutDownExpression(), D)
    #serv_reg_out_up = PSI.get_expression(container, ServedReserveOutUpExpression(), D)
    #serv_reg_out_down = PSI.get_expression(container, ServedReserveOutDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerOutVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            #p_out[ci_name, t] + (res_out_up[ci_name, t] - serv_reg_out_up[ci_name, t]) <=
            #max_limit * varon[ci_name, t]
            p_out[ci_name, t] + res_out_up[ci_name, t] <= max_limit * varon[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            #p_out[ci_name, t] -
            #(res_out_down[ci_name, t] - serv_reg_out_down[ci_name, t]) >= 0.0
            p_out[ci_name, t] - res_out_down[ci_name, t] >= 0.0
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusOutOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_statusout_withreserves!(container, T, devices, W())
    return
end

# Status In ON (Demand Operation)
function _add_constraints_statusin!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusInOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerInVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_in[ci_name, t] <= max_limit * (1.0 - varon[ci_name, t])
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusInOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_statusin!(container, T, devices, W())
    return
end

# Status In ON (Demand Operation) with Reserves
function _add_constraints_statusin_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusInOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    res_in_up = PSI.get_expression(container, TotalReserveInUpExpression(), D)
    res_in_down = PSI.get_expression(container, TotalReserveInDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerInVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_in[ci_name, t] + res_in_down[ci_name, t] <=
            max_limit * (1.0 - varon[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_in[ci_name, t] - res_in_up[ci_name, t] >= 0.0
        )
    end
    return
end

function _add_constraints_statusin_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusInOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.ReservationVariable(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    res_in_up = PSI.get_expression(container, TotalReserveInUpExpression(), D)
    res_in_down = PSI.get_expression(container, TotalReserveInDownExpression(), D)
    #serv_reg_in_up = PSI.get_expression(container, ServedReserveInUpExpression(), D)
    #serv_reg_in_down = PSI.get_expression(container, ServedReserveInDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerInVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            #p_in[ci_name, t] + (res_in_down[ci_name, t] - serv_reg_in_down[ci_name, t]) <=
            #max_limit * (1.0 - varon[ci_name, t])
            p_in[ci_name, t] + res_in_down[ci_name, t] <=
            max_limit * (1.0 - varon[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            #p_in[ci_name, t] - (res_in_up[ci_name, t] - serv_reg_in_up[ci_name, t]) >= 0.0
            p_in[ci_name, t] - res_in_up[ci_name, t] >= 0.0
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:StatusInOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_statusin_withreserves!(container, T, devices, W())
    return
end

############ Asset Balance Constraints, HybridSystem ###############
const JUMP_SET_TYPE = JuMP.Containers.DenseAxisArray{
    JuMP.VariableRef,
    1,
    Tuple{UnitRange{Int64}},
    Tuple{JuMP.Containers._AxisLookup{Tuple{Int64, Int64}}},
}

function _add_constraints_energyassetbalance!(
    container::PSI.OptimizationContainer,
    T::Type{<:EnergyAssetBalance},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    con_bal = PSI.add_constraints_container!(container, T(), D, names, time_steps)

    for device in devices
        ci_name = PSY.get_name(device)
        vars_pos = Set{JUMP_SET_TYPE}()
        vars_neg = Set{JUMP_SET_TYPE}()
        load_set = Set()

        if !isnothing(PSY.get_thermal_unit(device))
            p_th = PSI.get_variable(container, ThermalPower(), D)
            push!(vars_pos, p_th[ci_name, :])
        end
        if !isnothing(PSY.get_renewable_unit(device))
            p_re = PSI.get_variable(container, RenewablePower(), D)
            push!(vars_pos, p_re[ci_name, :])
        end
        if !isnothing(PSY.get_storage(device))
            p_ch = PSI.get_variable(container, BatteryCharge(), D)
            p_ds = PSI.get_variable(container, BatteryDischarge(), D)
            push!(vars_pos, p_ds[ci_name, :])
            push!(vars_neg, p_ch[ci_name, :])
        end
        if !isnothing(PSY.get_electric_load(device))
            P = ElectricLoadTimeSeries
            param_container = PSI.get_parameter(container, P(), D)
            param = PSI.get_parameter_column_refs(param_container, ci_name).data
            multiplier = PSY.get_max_active_power(PSY.get_electric_load(device))
            push!(load_set, param * multiplier)
        end
        for t in time_steps
            total_power = -p_out[ci_name, t] + p_in[ci_name, t]
            for vp in vars_pos
                JuMP.add_to_expression!(total_power, vp[t])
            end
            for vn in vars_neg
                JuMP.add_to_expression!(total_power, -vn[t])
            end
            for load in load_set
                JuMP.add_to_expression!(total_power, -load[t])
            end
            con_bal[ci_name, t] =
                JuMP.@constraint(PSI.get_jump_model(container), total_power == 0.0)
        end
    end
    return
end

function _add_constraints_energyassetbalance_with_reserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:EnergyAssetBalance},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    serv_reg_out_up = PSI.get_expression(container, ServedReserveOutUpExpression(), D)
    serv_reg_out_down = PSI.get_expression(container, ServedReserveOutDownExpression(), D)
    serv_reg_in_up = PSI.get_expression(container, ServedReserveInUpExpression(), D)
    serv_reg_in_down = PSI.get_expression(container, ServedReserveInDownExpression(), D)
    con_bal = PSI.add_constraints_container!(container, T(), D, names, time_steps)

    for device in devices
        ci_name = PSY.get_name(device)
        vars_pos = Set{JUMP_SET_TYPE}()
        vars_neg = Set{JUMP_SET_TYPE}()
        load_set = Set()
        expr_pos = Set()
        expr_neg = Set()

        if !isnothing(PSY.get_thermal_unit(device))
            p_th = PSI.get_variable(container, ThermalPower(), D)
            push!(vars_pos, p_th[ci_name, :])
        end
        if !isnothing(PSY.get_renewable_unit(device))
            p_re = PSI.get_variable(container, RenewablePower(), D)
            push!(vars_pos, p_re[ci_name, :])
        end
        if !isnothing(PSY.get_storage(device))
            p_ch = PSI.get_variable(container, BatteryCharge(), D)
            p_ds = PSI.get_variable(container, BatteryDischarge(), D)
            push!(vars_pos, p_ds[ci_name, :])
            push!(vars_neg, p_ch[ci_name, :])
        end
        if !isnothing(PSY.get_electric_load(device))
            P = ElectricLoadTimeSeries
            param_container = PSI.get_parameter(container, P(), D)
            param = PSI.get_parameter_column_refs(param_container, ci_name).data
            multiplier = PSY.get_max_active_power(PSY.get_electric_load(device))
            push!(load_set, param * multiplier)
        end
        # Add Served Fraction services
        push!(expr_pos, serv_reg_out_up[ci_name, :])
        push!(expr_neg, serv_reg_in_up[ci_name, :])
        push!(expr_neg, serv_reg_out_down[ci_name, :])
        push!(expr_pos, serv_reg_in_down[ci_name, :])
        for t in time_steps
            total_power = -p_out[ci_name, t] + p_in[ci_name, t]
            for vp in vars_pos
                JuMP.add_to_expression!(total_power, vp[t])
            end
            for vn in vars_neg
                JuMP.add_to_expression!(total_power, -vn[t])
            end
            for ep in expr_pos
                JuMP.add_to_expression!(total_power, ep[t])
            end
            for en in expr_neg
                JuMP.add_to_expression!(total_power, -en[t])
            end
            for load in load_set
                JuMP.add_to_expression!(total_power, -load[t])
            end
            con_bal[ci_name, t] =
                JuMP.@constraint(PSI.get_jump_model(container), total_power == 0.0)
        end
    end
    return
end

function add_expressions!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    devices::U,
) where {
    T <: AssetPowerBalance,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.HybridSystem}
    names = PSY.get_name.(devices)
    time_steps = PSI.get_time_steps(container)
    exp_container = PSI.add_expression_container!(container, T(), D, names, time_steps)
    for device in devices
        ci_name = PSY.get_name(device)
        vars_pos = Set{JUMP_SET_TYPE}()
        vars_neg = Set{JUMP_SET_TYPE}()
        load_set = Set()

        if !isnothing(PSY.get_thermal_unit(device))
            p_th = PSI.get_variable(container, ThermalPower(), D)
            push!(vars_pos, p_th[ci_name, :])
        end
        if !isnothing(PSY.get_renewable_unit(device))
            p_re = PSI.get_variable(container, RenewablePower(), D)
            push!(vars_pos, p_re[ci_name, :])
        end
        if !isnothing(PSY.get_storage(device))
            p_ch = PSI.get_variable(container, BatteryCharge(), D)
            p_ds = PSI.get_variable(container, BatteryDischarge(), D)
            push!(vars_pos, p_ds[ci_name, :])
            push!(vars_neg, p_ch[ci_name, :])
        end
        if !isnothing(PSY.get_electric_load(device))
            P = ElectricLoadTimeSeries
            param_container = PSI.get_parameter(container, P(), D)
            param = PSI.get_parameter_column_refs(param_container, ci_name).data
            multiplier = PSY.get_max_active_power(PSY.get_electric_load(device))
            push!(load_set, param * multiplier)
        end
        for t in time_steps
            for vp in vars_pos
                JuMP.add_to_expression!(exp_container[ci_name, t], vp[t])
            end
            for vn in vars_neg
                JuMP.add_to_expression!(exp_container[ci_name, t], -vn[t])
            end
            for load in load_set
                JuMP.add_to_expression!(exp_container[ci_name, t], -load[t])
            end
        end
    end
    return
end

function PSI.add_expressions!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    devices::U,
    model::PSI.DeviceModel{D, W},
) where {
    T <: AssetPowerBalance,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    add_expressions!(container, T, devices)
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:EnergyAssetBalance},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_energyassetbalance!(container, T, devices, W())
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:EnergyAssetBalance},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulationWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_energyassetbalance_with_reserves!(container, T, devices, W())
    return
end

############## Thermal Constraints, HybridSystem ###################

# ThermalOn Variable ON
function _add_constraints_thermalon_variableon!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalOnVariableUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device)).max
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] <= max_limit * varon[ci_name, t]
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalOnVariableUb},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_thermalon_variableon!(container, T, devices, W())
    return
end

# ThermalOn Variable OFF
function _add_constraints_thermalon_variableoff!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalOnVariableLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        min_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device)).min
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            min_limit * varon[ci_name, t] <= p_th[ci_name, t]
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalOnVariableLb},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_thermalon_variableoff!(container, T, devices, W())
    return
end

############## Storage Constraints, HybridSystem ###################

#BatteryStatus Charge ON
function _add_constraints_batterychargeon!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryStatusChargeOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    status_st = PSI.get_variable(container, BatteryStatus(), D)
    p_ch = PSI.get_variable(container, BatteryCharge(), D)
    con_ub_ch =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_input_active_power_limits(PSY.get_storage(device)).max
        con_ub_ch[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ch[ci_name, t] <= (1.0 - status_st[ci_name, t]) * max_limit
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryStatusChargeOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_batterychargeon!(container, T, devices, W())
    return
end

# BatteryStatus Discharge ON
function _add_constraints_batterydischargeon!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryStatusDischargeOn},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    status_st = PSI.get_variable(container, BatteryStatus(), D)
    p_ds = PSI.get_variable(container, BatteryDischarge(), D)
    con_ub_ds =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_output_active_power_limits(PSY.get_storage(device)).max
        con_ub_ds[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ds[ci_name, t] <= status_st[ci_name, t] * max_limit
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryStatusDischargeOn},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_batterydischargeon!(container, T, devices, W())
    return
end

# Battery Balance
function _add_constraints_batterybalance!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryBalance},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    con_soc = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)

    for ic in initial_conditions
        device = PSI.get_component(ic)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        con_soc[ci_name, 1] = JuMP.@constraint(
            PSI.get_jump_model(container),
            energy_var[ci_name, 1] ==
            PSI.get_value(ic) +
            fraction_of_hour * (
                charge_var[ci_name, 1] * efficiency.in -
                (discharge_var[ci_name, 1] / efficiency.out)
            )
        )

        for t in time_steps[2:end]
            con_soc[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                energy_var[ci_name, t] ==
                energy_var[ci_name, t - 1] +
                fraction_of_hour * (
                    charge_var[ci_name, t] * efficiency.in -
                    (discharge_var[ci_name, t] / efficiency.out)
                )
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryBalance},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_batterybalance!(container, T, devices, W())
    return
end

# Battery Balance
function _add_constraints_batterybalance_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryBalance},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    con_soc = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)

    for ic in initial_conditions
        device = PSI.get_component(ic)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        services = PSY.get_services(device)
        ch_expr_pos = Set()
        ch_expr_neg = Set()
        ds_expr_pos = Set()
        ds_expr_neg = Set()
        for service in services
            fraction = PSY.get_deployed_fraction(service)
            service_name = PSY.get_name(service)
            ch_reserve_var = PSI.get_variable(
                container,
                ChargingReserveVariable(),
                typeof(service),
                service_name,
            )
            ds_reserve_var = PSI.get_variable(
                container,
                DischargingReserveVariable(),
                typeof(service),
                service_name,
            )
            if isa(service, PSY.Reserve{PSY.ReserveUp})
                push!(ds_expr_pos, fraction * ds_reserve_var)
                push!(ch_expr_neg, fraction * ch_reserve_var)
            elseif isa(service, PSY.Reserve{PSY.ReserveDown})
                push!(ds_expr_neg, fraction * ds_reserve_var)
                push!(ch_expr_pos, fraction * ch_reserve_var)
            else
                error("Not supported type of service $(service_name)")
            end
        end
        tot_discharge_res = JuMP.AffExpr()
        tot_charge_res = JuMP.AffExpr()
        for v in ds_expr_pos
            tot_discharge_res += v[ci_name, 1]
        end
        for v in ds_expr_neg
            tot_discharge_res -= v[ci_name, 1]
        end
        for v in ch_expr_pos
            tot_charge_res += v[ci_name, 1]
        end
        for v in ch_expr_neg
            tot_charge_res -= v[ci_name, 1]
        end

        con_soc[ci_name, 1] = JuMP.@constraint(
            PSI.get_jump_model(container),
            energy_var[ci_name, 1] ==
            PSI.get_value(ic) +
            fraction_of_hour * (
                (charge_var[ci_name, 1] + tot_charge_res) * efficiency.in -
                ((discharge_var[ci_name, 1] + tot_discharge_res) / efficiency.out)
            )
        )

        for t in time_steps[2:end]
            tot_discharge_res = JuMP.AffExpr()
            tot_charge_res = JuMP.AffExpr()
            for v in ds_expr_pos
                tot_discharge_res += v[ci_name, t]
            end
            for v in ds_expr_neg
                tot_discharge_res -= v[ci_name, t]
            end
            for v in ch_expr_pos
                tot_charge_res += v[ci_name, t]
            end
            for v in ch_expr_neg
                tot_charge_res -= v[ci_name, t]
            end
            con_soc[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                energy_var[ci_name, t] ==
                energy_var[ci_name, t - 1] +
                fraction_of_hour * (
                    (charge_var[ci_name, t] + tot_charge_res) * efficiency.in -
                    ((discharge_var[ci_name, t] + tot_discharge_res) / efficiency.out)
                )
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:BatteryBalance},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_batterybalance_withreserves!(container, T, devices, W())
    return
end

# Cycling Charge
function _add_constraints_cyclingcharge!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingCharge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    con_cycling_ch = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        #if PSI.built_for_recurrent_solves(container)
        #    param_value =
        #        PSI.get_parameter_array(container, CyclingChargeLimitParameter(), D)[ci_name]
        #    con_cycling_ch[ci_name] = JuMP.@constraint(
        #        PSI.get_jump_model(container),
        #        efficiency.in * fraction_of_hour * sum(charge_var[ci_name, :]) <=
        #        param_value
        #    )
        #else
        E_max = PSY.get_storage_level_limits(storage).max
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        con_cycling_ch[ci_name] = JuMP.@constraint(
            PSI.get_jump_model(container),
            efficiency.in * fraction_of_hour * sum(charge_var[ci_name, :]) <=
            cycles_in_horizon * E_max
        )
        #end
    end
    return
end

function _add_constraints_cyclingcharge_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingCharge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    ch_served_reg_up = PSI.get_expression(container, ChargeServedReserveUpExpression(), D)
    ch_served_reg_dn = PSI.get_expression(container, ChargeServedReserveDownExpression(), D)
    con_cycling_ch = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
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
        #=
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingChargeLimitParameter(), D)[ci_name]
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
        =#
    end
    return
end

function _add_constraints_cyclingcharge_decisionmodel!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingCharge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    con_cycling_ch = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
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
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingCharge},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    if PSI.get_attribute(model, "cycling")
        has_services = PSI.has_service_model(model)
        if !has_services
            _add_constraints_cyclingcharge!(container, T, devices, W())
        else
            _add_constraints_cyclingcharge_withreserves!(container, T, devices, W())
        end
    end
    return
end

# Cycling Discharge
function _add_constraints_cyclingdischarge!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingDischarge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    con_cycling_ds = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        #if PSI.built_for_recurrent_solves(container)
        #    param_value =
        #        PSI.get_parameter_array(container, CyclingDischargeLimitParameter(), D)[ci_name]
        #    con_cycling_ds[ci_name] = JuMP.@constraint(
        #        PSI.get_jump_model(container),
        #        (1.0 / efficiency.out) *
        #        fraction_of_hour *
        #        sum(discharge_var[ci_name, :]) <= param_value
        #    )
        #else
        E_max = PSY.get_storage_level_limits(storage).max
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        con_cycling_ds[ci_name] = JuMP.@constraint(
            PSI.get_jump_model(container),
            (1.0 / efficiency.out) * fraction_of_hour * sum(discharge_var[ci_name, :]) <= cycles_in_horizon * E_max
        )
        #end
    end
    return
end

function _add_constraints_cyclingdischarge_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingDischarge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    ds_served_reg_up =
        PSI.get_expression(container, DischargeServedReserveUpExpression(), D)
    ds_served_reg_dn =
        PSI.get_expression(container, DischargeServedReserveDownExpression(), D)
    con_cycling_ds = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
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
        #=
        if PSI.built_for_recurrent_solves(container)
            param_value =
                PSI.get_parameter_array(container, CyclingDischargeLimitParameter(), D)[ci_name]
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
        =#
    end
    return
end

function _add_constraints_cyclingdischarge_decisionmodel!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingDischarge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    con_cycling_ds = PSI.add_constraints_container!(container, T(), D, names)
    for device in devices
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)

        E_max = PSY.get_storage_level_limits(storage).max
        cycles_per_day = PSY.get_cycle_limits(storage)
        cycles_in_horizon =
            cycles_per_day * fraction_of_hour * length(time_steps) / HOURS_IN_DAY
        con_cycling_ds[ci_name] = JuMP.@constraint(
            PSI.get_jump_model(container),
            (1.0 / efficiency.out) * fraction_of_hour * sum(discharge_var[ci_name, :]) <= cycles_in_horizon * E_max
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:CyclingDischarge},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    if PSI.get_attribute(model, "cycling")
        has_services = PSI.has_service_model(model)
        if !has_services
            _add_constraints_cyclingdischarge!(container, T, devices, W())
        else
            _add_constraints_cyclingdischarge_withreserves!(container, T, devices, W())
        end
    end
    return
end

# Target Constraint
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    ::Type{StateofChargeTargetConstraint},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    surplus_var = PSI.get_variable(container, BatteryEnergySurplusVariable(), D)
    shortfall_var = PSI.get_variable(container, BatteryEnergyShortageVariable(), D)

    device_names, time_steps = axes(energy_var)
    constraint_container = PSI.add_constraints_container!(
        container,
        StateofChargeTargetConstraint(),
        D,
        device_names,
    )

    for d in devices
        name = PSY.get_name(d)
        storage = PSY.get_storage(d)
        target = PSY.get_storage_target(storage)
        constraint_container[name] = JuMP.@constraint(
            PSI.get_jump_model(container),
            energy_var[name, time_steps[end]] - surplus_var[name] + shortfall_var[name] == target
        )
    end

    return
end

# Regularization Charge
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    ::Type{ChargeRegularizationConstraint},
    devices::U,
    model::PSI.DeviceModel{V, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    W <: AbstractHybridFormulation,
} where {V <: PSY.HybridSystem}
    names = [PSY.get_name(x) for x in devices]
    time_steps = PSI.get_time_steps(container)
    reg_var = PSI.get_variable(container, ChargeRegularizationVariable(), V)
    powerin_var = PSI.get_variable(container, BatteryCharge(), V)
    has_services = PSI.has_service_model(model)
    if has_services
    end
    constraint_ub = PSI.add_constraints_container!(
        container,
        ChargeRegularizationConstraint(),
        V,
        names,
        time_steps,
        meta="ub",
    )

    constraint_lb = PSI.add_constraints_container!(
        container,
        ChargeRegularizationConstraint(),
        V,
        names,
        time_steps,
        meta="lb",
    )

    if has_services
        ch_served_reg_up =
            PSI.get_expression(container, ChargeServedReserveUpExpression(), V)
        ch_served_reg_dn =
            PSI.get_expression(container, ChargeServedReserveDownExpression(), V)
        for device in devices
            ci_name = PSY.get_name(device)
            constraint_ub[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            constraint_lb[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            for t in time_steps[2:end]
                constraint_ub[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    (
                        powerin_var[ci_name, t - 1] - ch_served_reg_up[ci_name, t - 1] +
                        ch_served_reg_dn[ci_name, t - 1]
                    ) - (
                        powerin_var[ci_name, t] - ch_served_reg_up[ci_name, t] +
                        ch_served_reg_dn[ci_name, t]
                    ) <= reg_var[ci_name, t]
                )
                constraint_lb[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    (
                        powerin_var[ci_name, t - 1] - ch_served_reg_up[ci_name, t - 1] +
                        ch_served_reg_dn[ci_name, t - 1]
                    ) - (
                        powerin_var[ci_name, t] - ch_served_reg_up[ci_name, t] +
                        ch_served_reg_dn[ci_name, t]
                    ) >= -reg_var[ci_name, t]
                )
            end
        end
    else # No Services
        for device in devices
            ci_name = PSY.get_name(device)
            constraint_ub[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            constraint_lb[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            for t in time_steps[2:end]
                constraint_ub[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    powerin_var[ci_name, t - 1] - powerin_var[ci_name, t] <=
                    reg_var[ci_name, t]
                )
                constraint_lb[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    powerin_var[ci_name, t - 1] - powerin_var[ci_name, t] >=
                    -reg_var[ci_name, t]
                )
            end
        end
    end
    return
end

# Regularization Discharge
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    ::Type{DischargeRegularizationConstraint},
    devices::U,
    model::PSI.DeviceModel{V, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    W <: AbstractHybridFormulation,
} where {V <: PSY.HybridSystem}
    names = [PSY.get_name(x) for x in devices]
    time_steps = PSI.get_time_steps(container)
    reg_var = PSI.get_variable(container, DischargeRegularizationVariable(), V)
    powerout_var = PSI.get_variable(container, BatteryDischarge(), V)
    has_services = PSI.has_service_model(model)

    constraint_ub = PSI.add_constraints_container!(
        container,
        DischargeRegularizationConstraint(),
        V,
        names,
        time_steps,
        meta="ub",
    )

    constraint_lb = PSI.add_constraints_container!(
        container,
        DischargeRegularizationConstraint(),
        V,
        names,
        time_steps,
        meta="lb",
    )

    if has_services
        ds_served_reg_up =
            PSI.get_expression(container, DischargeServedReserveUpExpression(), V)
        ds_served_reg_dn =
            PSI.get_expression(container, DischargeServedReserveDownExpression(), V)
        for device in devices
            ci_name = PSY.get_name(device)
            constraint_ub[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            constraint_lb[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            for t in time_steps[2:end]
                constraint_ub[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    (
                        powerout_var[ci_name, t - 1] + ds_served_reg_up[ci_name, t - 1] -
                        ds_served_reg_dn[ci_name, t - 1]
                    ) - (
                        powerout_var[ci_name, t] + ds_served_reg_up[ci_name, t] -
                        ds_served_reg_dn[ci_name, t]
                    ) <= reg_var[ci_name, t]
                )
                constraint_lb[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    (
                        powerout_var[ci_name, t - 1] + ds_served_reg_up[ci_name, t - 1] -
                        ds_served_reg_dn[ci_name, t - 1]
                    ) - (
                        powerout_var[ci_name, t] + ds_served_reg_up[ci_name, t] -
                        ds_served_reg_dn[ci_name, t]
                    ) >= -reg_var[ci_name, t]
                )
            end
        end
    else # No Services
        for device in devices
            ci_name = PSY.get_name(device)
            constraint_ub[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            constraint_lb[ci_name, 1] =
                JuMP.@constraint(PSI.get_jump_model(container), reg_var[ci_name, 1] == 0)
            for t in time_steps[2:end]
                constraint_ub[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    powerout_var[ci_name, t - 1] - powerout_var[ci_name, t] <=
                    reg_var[ci_name, t]
                )
                constraint_lb[ci_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    powerout_var[ci_name, t - 1] - powerout_var[ci_name, t] >=
                    -reg_var[ci_name, t]
                )
            end
        end
    end
    return
end

############## Renewable Constraints, HybridSystem ###################

function _add_constraints_renewablelimit!(
    container::PSI.OptimizationContainer,
    T::Type{<:RenewableActivePowerLimitConstraint},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    p_re = PSI.get_variable(container, RenewablePower(), D)
    names = [PSY.get_name(d) for d in devices]
    con_ub_re =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    param_container = PSI.get_parameter(container, RenewablePowerTimeSeries(), D)
    for device in devices
        ci_name = PSY.get_name(device)
        multiplier = PSY.get_max_active_power(device.renewable_unit)
        param = PSI.get_parameter_column_refs(param_container, ci_name)
        for t in time_steps
            con_ub_re[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                p_re[ci_name, t] <= multiplier * param[t]
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:RenewableActivePowerLimitConstraint},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    _add_constraints_renewablelimit!(container, T, devices, W())
    return
end

############## Thermal Constraints ReserveLimit, HybridSystem ###################

function _add_thermallimit_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalReserveLimit},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    reg_th_up = PSI.get_expression(container, ThermalReserveUpExpression(), D)
    reg_th_dn = PSI.get_expression(container, ThermalReserveDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        min_limit, max_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device))
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] + reg_th_up[ci_name, t] <= max_limit * varon[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] - reg_th_dn[ci_name, t] >= min_limit * varon[ci_name, t]
        )
    end
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalReserveLimit},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_thermallimit_withreserves!(container, T, devices, W())
    return
end

############## Storage Constraints ReserveLimit, HybridSystem ###################

# Range Constraint Coverage Discharge (RegUp)
function _add_constraints_reservecoverage_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:ReserveCoverageConstraint},
    devices::U,
    service::V,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveUp},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    sustained_time = PSY.get_sustained_time(service) # in seconds
    num_periods = sustained_time / Dates.value(Dates.Second(resolution))
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    service_name = PSY.get_name(service)
    reserve_var = PSI.get_variable(container, DischargingReserveVariable(), V, service_name)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(
        container,
        T(),
        D,
        names,
        time_steps,
        meta=service_name,
    )
    for ic in initial_conditions
        device = PSI.get_component(ic)
        # TODO FIX: This assert will trigger if we have a hybrid that does not participate in a specific service but others do
        @assert service in PSY.get_services(device)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        inv_efficiency = 1.0 / PSY.get_efficiency(storage).out
        sustained_param = inv_efficiency * fraction_of_hour * num_periods
        con[ci_name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            sustained_param * reserve_var[ci_name, 1] <= PSI.get_value(ic)
        )
        for t in time_steps[2:end]
            con[ci_name, t] = JuMP.@constraint(
                container.JuMPmodel,
                sustained_param * reserve_var[ci_name, t] <= energy_var[ci_name, t - 1]
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ReserveCoverageConstraint},
    devices::U,
    service::V,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveUp},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_reservecoverage_withreserves!(container, T, devices, service, W())
    return
end

# Range Constraint Coverage Charge (RegDown)
function _add_constraints_reservecoverage_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:ReserveCoverageConstraint},
    devices::U,
    service::V,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveDown},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    sustained_time = PSY.get_sustained_time(service) # in seconds
    num_periods = sustained_time / Dates.value(Dates.Second(resolution))
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    service_name = PSY.get_name(service)
    reserve_var = PSI.get_variable(container, ChargingReserveVariable(), V, service_name)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(
        container,
        T(),
        D,
        names,
        time_steps,
        meta=service_name,
    )
    for ic in initial_conditions
        device = PSI.get_component(ic)
        # TODO FIX: This assert will trigger if we have a hybrid that does not participate in a specific service but others do
        @assert service in PSY.get_services(device)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage).in
        E_max = PSY.get_storage_level_limits(storage).max
        sustained_param = efficiency * num_periods * fraction_of_hour
        con[ci_name, 1] = JuMP.@constraint(
            container.JuMPmodel,
            sustained_param * reserve_var[ci_name, 1] <= E_max - PSI.get_value(ic)
        )
        for t in time_steps[2:end]
            con[ci_name, t] = JuMP.@constraint(
                container.JuMPmodel,
                sustained_param * reserve_var[ci_name, t] <=
                E_max - energy_var[ci_name, t - 1]
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ReserveCoverageConstraint},
    devices::U,
    service::V,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveDown},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_reservecoverage_withreserves!(container, T, devices, service, W())
    return
end

# Reserve Coverage Constraints End Of Period Discharge (RegUP)
function _add_constraints_reservecoverage_withreserves_endofperiod!(
    container::PSI.OptimizationContainer,
    T::Type{<:ReserveCoverageConstraintEndOfPeriod},
    devices::U,
    service::V,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveUp},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    sustained_time = PSY.get_sustained_time(service) # in seconds
    num_periods = sustained_time / Dates.value(Dates.Second(resolution))
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    service_name = PSY.get_name(service)
    reserve_var = PSI.get_variable(container, DischargingReserveVariable(), V, service_name)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(
        container,
        T(),
        D,
        names,
        time_steps,
        meta=service_name,
    )
    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        inv_efficiency = 1.0 / PSY.get_efficiency(storage).out
        sustained_param = inv_efficiency * fraction_of_hour * num_periods
        con[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            sustained_param * reserve_var[ci_name, t] <= energy_var[ci_name, t]
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ReserveCoverageConstraintEndOfPeriod},
    devices::U,
    service::V,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveUp},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_reservecoverage_withreserves_endofperiod!(
        container,
        T,
        devices,
        service,
        W(),
    )
    return
end

# Reserve Coverage Constraints End Of Period Charge (RegDown)
function _add_constraints_reservecoverage_withreserves_endofperiod!(
    container::PSI.OptimizationContainer,
    T::Type{<:ReserveCoverageConstraintEndOfPeriod},
    devices::U,
    service::V,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveDown},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    sustained_time = PSY.get_sustained_time(service) # in seconds
    num_periods = sustained_time / Dates.value(Dates.Second(resolution))
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    service_name = PSY.get_name(service)
    reserve_var = PSI.get_variable(container, ChargingReserveVariable(), V, service_name)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(
        container,
        T(),
        D,
        names,
        time_steps,
        meta=service_name,
    )
    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        E_max = PSY.get_storage_level_limits(storage).max
        efficiency = PSY.get_efficiency(storage).in
        sustained_param = efficiency * fraction_of_hour * num_periods
        con[ci_name, t] = JuMP.@constraint(
            container.JuMPmodel,
            sustained_param * reserve_var[ci_name, t] <= E_max - energy_var[ci_name, t]
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ReserveCoverageConstraintEndOfPeriod},
    devices::U,
    service::V,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    V <: PSY.Reserve{PSY.ReserveDown},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_reservecoverage_withreserves_endofperiod!(
        container,
        T,
        devices,
        service,
        W(),
    )
    return
end

# Charge Upper/Lower Reserve Limits
function _add_constraints_charging_reservelimit!(
    container::PSI.OptimizationContainer,
    T::Type{<:ChargingReservePowerLimit},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    status_st = PSI.get_variable(container, BatteryStatus(), D)
    p_ch = PSI.get_variable(container, BatteryCharge(), D)
    reg_ch_up = PSI.get_expression(container, ChargeReserveUpExpression(), D)
    reg_ch_dn = PSI.get_expression(container, ChargeReserveDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_input_active_power_limits(PSY.get_storage(device)).max
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ch[ci_name, t] + reg_ch_dn[ci_name, t] <=
            max_limit * (1.0 - status_st[ci_name, t])
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ch[ci_name, t] - reg_ch_up[ci_name, t] >= 0.0
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ChargingReservePowerLimit},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_charging_reservelimit!(container, T, devices, W())
    return
end

# Discharge Upper/Lower Reserve Limit
function _add_constraints_discharging_reservelimit!(
    container::PSI.OptimizationContainer,
    T::Type{<:DischargingReservePowerLimit},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    status_st = PSI.get_variable(container, BatteryStatus(), D)
    p_ds = PSI.get_variable(container, BatteryDischarge(), D)
    reg_ds_up = PSI.get_expression(container, DischargeReserveUpExpression(), D)
    reg_ds_dn = PSI.get_expression(container, DischargeReserveDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_input_active_power_limits(PSY.get_storage(device)).max
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ds[ci_name, t] + reg_ds_up[ci_name, t] <= max_limit * status_st[ci_name, t]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_ds[ci_name, t] - reg_ds_dn[ci_name, t] >= 0.0
        )
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:DischargingReservePowerLimit},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_discharging_reservelimit!(container, T, devices, W())
end

############## Renewable Constraints ReserveLimit, HybridSystem ###################

function _add_constraints_renewablereserve_limit!(
    container::PSI.OptimizationContainer,
    T::Type{<:RenewableReserveLimit},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    P = RenewablePowerTimeSeries
    names = [PSY.get_name(d) for d in devices]
    p_re = PSI.get_variable(container, RenewablePower(), D)
    reg_re_up = PSI.get_expression(container, RenewableReserveUpExpression(), D)
    reg_re_dn = PSI.get_expression(container, RenewableReserveDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")
    param_container = PSI.get_parameter(container, P(), D)
    for device in devices
        ci_name = PSY.get_name(device)
        multiplier = PSY.get_max_active_power(device.renewable_unit)
        param = PSI.get_parameter_column_refs(param_container, ci_name)
        for t in time_steps
            con_ub[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                p_re[ci_name, t] + reg_re_up[ci_name, t] <= multiplier * param[t]
            )
            con_lb[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                p_re[ci_name, t] - reg_re_dn[ci_name, t] >= 0.0
            )
        end
    end
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:RenewableReserveLimit},
    devices::U,
    ::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    _add_constraints_renewablereserve_limit!(container, T, devices, W())
    return
end

############## Reserve Balance and Output Constraints, HybridSystem ###################
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{HybridReserveAssignmentConstraint},
    devices::U,
    ::PSI.DeviceModel{D, W},
    ::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
    for service in services
        service_name = PSY.get_name(service)
        res_out =
            PSI.get_variable(container, ReserveVariableOut(), typeof(service), service_name)
        res_in =
            PSI.get_variable(container, ReserveVariableIn(), typeof(service), service_name)
        res_var = PSI.get_variable(
            container,
            PSI.ActivePowerReserveVariable(),
            typeof(service),
            service_name,
        )
        _, time_steps = axes(res_out)
        names = [PSY.get_name(d) for d in devices]
        con = PSI.add_constraints_container!(
            container,
            T(),
            D,
            names,
            time_steps,
            meta=service_name,
        )
        for device in devices, t in time_steps
            ci_name = PSY.get_name(device)
            con[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                res_out[ci_name, t] + res_in[ci_name, t] == res_var[ci_name, t]
            )
        end
    end
    return
end

function _add_constraints_reserve_assignment!(
    container::PSI.OptimizationContainer,
    T::Type{HybridReserveAssignmentConstraint},
    devices::U,
    in_var,
    out_var,
    assignment_var,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.HybridSystem}
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
    #time_steps = PSY.get_ext(first(devices))["T_da"]
    time_steps = PSI.get_time_steps(container)
    con = PSI.add_constraints_container!(
        container,
        T(),
        D,
        [PSY.get_name(d) for d in devices],
        PSY.get_name.(services),
        time_steps,
    )

    tmap = PSY.get_ext(first(devices))["tmap"]

    for service in services
        service_name = PSY.get_name(service)
        res_out = PSI.get_variable(container, out_var, typeof(service), service_name)
        res_in = PSI.get_variable(container, in_var, typeof(service), service_name)
        res_var = PSI.get_variable(container, assignment_var, D)
        for device in devices, t in time_steps
            horizon_DA = PSY.get_ext(device)["horizon_DA"]
            ci_name = PSY.get_name(device)
            if horizon_DA == 24
                slack_up = PSI.get_variable(container, SlackReserveUp(), D)
                slack_dn = PSI.get_variable(container, SlackReserveDown(), D)
                con[ci_name, service_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    res_out[ci_name, tmap[t]] + res_in[ci_name, tmap[t]] -
                    res_var[ci_name, service_name, t] -
                    slack_up[ci_name, service_name, t] +
                    slack_dn[ci_name, service_name, t] == 0.0
                )
            else
                con[ci_name, service_name, t] = JuMP.@constraint(
                    PSI.get_jump_model(container),
                    res_out[ci_name, tmap[t]] + res_in[ci_name, tmap[t]] -
                    res_var[ci_name, service_name, t] == 0.0
                )
            end
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{HybridReserveAssignmentConstraint},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridFixedDA,
} where {D <: PSY.HybridSystem}
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end

    for service in services
        time_steps = PSI.get_time_steps(container)
        service_name = PSY.get_name(service)
        res_assignment = PSI.get_variable(container, TotalReserve(), D)
        res_var = PSI.get_variable(
            container,
            PSI.ActivePowerReserveVariable(),
            typeof(service),
            service_name,
        )
        names = [PSY.get_name(d) for d in devices]
        con = PSI.add_constraints_container!(
            container,
            T(),
            D,
            names,
            time_steps,
            meta=service_name,
        )
        for device in devices, t in time_steps
            ci_name = PSY.get_name(device)
            con[ci_name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                res_assignment[ci_name, service_name, t] == res_var[ci_name, t]
            )
        end
    end
    return
end

function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ReserveBalance},
    devices::U,
    model::PSI.DeviceModel{D, W},
    network_model::PSI.NetworkModel{<:PM.AbstractPowerModel},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: HybridDispatchWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
    for service in services
        service_name = PSY.get_name(service)
        res_out =
            PSI.get_variable(container, ReserveVariableOut(), typeof(service), service_name)
        res_in =
            PSI.get_variable(container, ReserveVariableIn(), typeof(service), service_name)
        names = [PSY.get_name(d) for d in devices]
        con = PSI.add_constraints_container!(
            container,
            T(),
            D,
            names,
            time_steps,
            meta=service_name,
        )
        for device in devices
            ci_name = PSY.get_name(device)
            vars_pos = Set{JUMP_SET_TYPE}()

            if !isnothing(PSY.get_thermal_unit(device))
                res_th = PSI.get_variable(
                    container,
                    ThermalReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_th[ci_name, :])
            end
            if !isnothing(PSY.get_renewable_unit(device))
                res_re = PSI.get_variable(
                    container,
                    RenewableReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_re[ci_name, :])
            end
            if !isnothing(PSY.get_storage(device))
                res_ch = PSI.get_variable(
                    container,
                    ChargingReserveVariable(),
                    typeof(service),
                    service_name,
                )
                res_ds = PSI.get_variable(
                    container,
                    DischargingReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_ds[ci_name, :])
                push!(vars_pos, res_ch[ci_name, :])
            end
            for t in time_steps
                total_reserve = -res_out[ci_name, t] - res_in[ci_name, t]
                for vp in vars_pos
                    JuMP.add_to_expression!(total_reserve, vp[t])
                end
                con[ci_name, t] =
                    JuMP.@constraint(PSI.get_jump_model(container), total_reserve == 0.0)
            end
        end
    end
    return
end

###################################################################
################### Decision Model Constraints ####################
###################################################################

# Day-Ahead Out Bid PCC Range Limits
function add_constraints_dayaheadlimit_out_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:DayAheadBidOutRangeLimit},
    devices::U,
    ::W,
    time_steps::UnitRange{Int64},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    names = [PSY.get_name(d) for d in devices]
    bid_out = PSI.get_variable(container, EnergyDABidOut(), D)
    res_out_up = PSI.get_expression(container, TotalReserveOutUpExpression(), D)
    res_out_down = PSI.get_expression(container, TotalReserveOutDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerOutVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_out[ci_name, t] + res_out_up[ci_name, t] <= max_limit
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_out[ci_name, t] - res_out_down[ci_name, t] >= 0.0
        )
    end
    return
end

# Day-Ahead In Bid PCC Range Limits
function add_constraints_dayaheadlimit_in_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:DayAheadBidInRangeLimit},
    devices::U,
    ::W,
    time_steps::UnitRange{Int64},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    names = [PSY.get_name(d) for d in devices]
    bid_in = PSI.get_variable(container, EnergyDABidIn(), D)
    res_in_up = PSI.get_expression(container, TotalReserveInUpExpression(), D)
    res_in_down = PSI.get_expression(container, TotalReserveInDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerInVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_in[ci_name, t] + res_in_down[ci_name, t] <= max_limit
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_in[ci_name, t] - res_in_up[ci_name, t] >= 0.0
        )
    end
    return
end

# Real-Time Out Bid PCC Range Limits
function add_constraints_realtimelimit_out_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:RealTimeBidOutRangeLimit},
    devices::U,
    ::W,
    time_steps::UnitRange{Int64},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    names = [PSY.get_name(d) for d in devices]
    bid_out = PSI.get_variable(container, EnergyRTBidOut(), D)
    res_out_up = PSI.get_expression(container, TotalReserveOutUpExpression(), D)
    res_out_down = PSI.get_expression(container, TotalReserveOutDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerOutVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_out[ci_name, t] + res_out_up[ci_name, tmap[t]] <= max_limit
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_out[ci_name, t] - res_out_down[ci_name, tmap[t]] >= 0.0
        )
    end
    return
end

# Day-Ahead In Bid PCC Range Limits
function add_constraints_realtimelimit_in_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:RealTimeBidInRangeLimit},
    devices::U,
    ::W,
    time_steps::UnitRange{Int64},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    names = [PSY.get_name(d) for d in devices]
    bid_in = PSI.get_variable(container, EnergyRTBidIn(), D)
    res_in_up = PSI.get_expression(container, TotalReserveInUpExpression(), D)
    res_in_down = PSI.get_expression(container, TotalReserveInDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        max_limit = PSI.get_variable_upper_bound(PSI.ActivePowerInVariable(), device, W())
        @assert max_limit !== nothing ci_name
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_in[ci_name, t] + res_in_down[ci_name, tmap[t]] <= max_limit
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_in[ci_name, t] - res_in_up[ci_name, tmap[t]] >= 0.0
        )
    end
    return
end

# Thermal Reserve Limit with Merchant Model
function _add_thermallimit_withreserves!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalReserveLimit},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    reg_th_up = PSI.get_expression(container, ThermalReserveUpExpression(), D)
    reg_th_dn = PSI.get_expression(container, ThermalReserveDownExpression(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        min_limit, max_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device))
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] + reg_th_up[ci_name, t] <= max_limit * varon[ci_name, tmap[t]]
        )
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] - reg_th_dn[ci_name, t] >= min_limit * varon[ci_name, tmap[t]]
        )
    end
end

# Thermal Reserve Limit with Reserve Model
function _add_constraints_thermalon_variableon!(
    container::PSI.OptimizationContainer,
    T::Type{ThermalOnVariableUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    con_ub = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="ub")

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        max_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device)).max
        con_ub[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            p_th[ci_name, t] <= max_limit * varon[ci_name, tmap[t]]
        )
    end
    return
end

# ThermalOn Variable OFF for Merchant Model
function _add_constraints_thermalon_variableoff!(
    container::PSI.OptimizationContainer,
    T::Type{<:ThermalOnVariableLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    p_th = PSI.get_variable(container, ThermalPower(), D)
    con_lb = PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="lb")

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        min_limit = PSY.get_active_power_limits(PSY.get_thermal_unit(device)).min
        con_lb[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            min_limit * varon[ci_name, tmap[t]] <= p_th[ci_name, t]
        )
    end
    return
end

# Energy Bid Balance in RT
function _add_constraints_energybidassetbalance!(
    container::PSI.OptimizationContainer,
    T::Type{<:EnergyBidAssetBalance},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: AbstractHybridFormulation,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    bid_out = PSI.get_variable(container, EnergyRTBidOut(), D)
    bid_in = PSI.get_variable(container, EnergyRTBidIn(), D)
    con_bal = PSI.add_constraints_container!(container, T(), D, names, time_steps)

    # Make Expression for this balance
    for device in devices
        ci_name = PSY.get_name(device)
        vars_pos = Set{JUMP_SET_TYPE}()
        vars_neg = Set{JUMP_SET_TYPE}()
        load_set = Set()

        if !isnothing(PSY.get_thermal_unit(device))
            bid_th = PSI.get_variable(container, EnergyThermalBid(), D)
            push!(vars_pos, bid_th[ci_name, :])
        end
        if !isnothing(PSY.get_renewable_unit(device))
            bid_re = PSI.get_variable(container, EnergyRenewableBid(), D)
            push!(vars_pos, bid_re[ci_name, :])
        end
        if !isnothing(PSY.get_storage(device))
            bid_ch = PSI.get_variable(container, EnergyBatteryChargeBid(), D)
            bid_ds = PSI.get_variable(container, EnergyBatteryDischargeBid(), D)
            push!(vars_pos, bid_ds[ci_name, :])
            push!(vars_neg, bid_ch[ci_name, :])
        end
        if !isnothing(PSY.get_electric_load(device))
            P = ElectricLoadTimeSeries
            param_container = PSI.get_parameter(container, P(), D)
            param = PSI.get_parameter_column_refs(param_container, ci_name).data
            multiplier = PSY.get_max_active_power(PSY.get_electric_load(device))
            push!(load_set, param * multiplier)
        end
        for t in time_steps
            total_power = -bid_out[ci_name, t] + bid_in[ci_name, t]
            for vp in vars_pos
                JuMP.add_to_expression!(total_power, vp[t])
            end
            for vn in vars_neg
                JuMP.add_to_expression!(total_power, -vn[t])
            end
            for load in load_set
                JuMP.add_to_expression!(total_power, -load[t])
            end
            con_bal[ci_name, t] =
                JuMP.@constraint(PSI.get_jump_model(container), total_power == 0.0)
        end
    end
    return
end

# Product Ancillary Service Balance
function _add_constraints_reservebalance!(
    container::PSI.OptimizationContainer,
    T::Type{<:ReserveBalance},
    devices::U,
    ::W,
    time_steps::UnitRange{Int64},
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end
    for service in services
        service_name = PSY.get_name(service)
        res_out = PSI.get_variable(
            container,
            BidReserveVariableOut(),
            typeof(service),
            service_name,
        )
        res_in = PSI.get_variable(
            container,
            BidReserveVariableIn(),
            typeof(service),
            service_name,
        )
        names = [PSY.get_name(d) for d in devices]
        con = PSI.add_constraints_container!(
            container,
            T(),
            D,
            names,
            time_steps,
            meta=service_name,
        )
        for device in devices
            tmap = PSY.get_ext(device)["tmap"]
            ci_name = PSY.get_name(device)
            vars_pos = Set{JUMP_SET_TYPE}()

            if !isnothing(PSY.get_thermal_unit(device))
                res_th = PSI.get_variable(
                    container,
                    ThermalReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_th[ci_name, :])
            end
            if !isnothing(PSY.get_renewable_unit(device))
                res_re = PSI.get_variable(
                    container,
                    RenewableReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_re[ci_name, :])
            end
            if !isnothing(PSY.get_storage(device))
                res_ch = PSI.get_variable(
                    container,
                    ChargingReserveVariable(),
                    typeof(service),
                    service_name,
                )
                res_ds = PSI.get_variable(
                    container,
                    DischargingReserveVariable(),
                    typeof(service),
                    service_name,
                )
                push!(vars_pos, res_ds[ci_name, :])
                push!(vars_pos, res_ch[ci_name, :])
            end
            for t in time_steps
                total_reserve = -res_out[ci_name, tmap[t]] - res_in[ci_name, tmap[t]]
                for vp in vars_pos
                    JuMP.add_to_expression!(total_reserve, vp[t])
                end
                con[ci_name, t] =
                    JuMP.@constraint(PSI.get_jump_model(container), total_reserve == 0.0)
            end
        end
    end
    return
end

# Market Out Convergence
function _add_constraints_out_marketconvergence!(
    container::PSI.OptimizationContainer,
    T::Type{<:MarketOutConvergence},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    bid_out = PSI.get_variable(container, EnergyRTBidOut(), D)
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), D)
    res_out_up = PSI.get_expression(container, ServedReserveOutUpExpression(), D)
    res_out_down = PSI.get_expression(container, ServedReserveOutDownExpression(), D)
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        con[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_out[ci_name, t] + res_out_up[ci_name, tmap[t]] -
            res_out_down[ci_name, tmap[t]] == p_out[ci_name, t]
        )
    end
    return
end

function _add_constraints_in_marketconvergence!(
    container::PSI.OptimizationContainer,
    T::Type{<:MarketInConvergence},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    bid_in = PSI.get_variable(container, EnergyRTBidIn(), D)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), D)
    res_in_up = PSI.get_expression(container, ServedReserveInUpExpression(), D)
    res_in_down = PSI.get_expression(container, ServedReserveInDownExpression(), D)
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)

    for device in devices, t in time_steps
        tmap = PSY.get_ext(device)["tmap"]
        ci_name = PSY.get_name(device)
        con[ci_name, t] = JuMP.@constraint(
            PSI.get_jump_model(container),
            bid_in[ci_name, t] + res_in_down[ci_name, tmap[t]] -
            res_in_up[ci_name, tmap[t]] == p_in[ci_name, t]
        )
    end
    return
end

###################################################################
###################################################################
################### Bi-level KKT Constraints  #####################
###################################################################
###################################################################

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{OptConditionThermalPower},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    λUb_var = PSI.get_variable(container, λUb(), D)
    λLb_var = PSI.get_variable(container, λLb(), D)
    μThUb_var = PSI.get_variable(container, μThUb(), D)
    μThLb_var = PSI.get_variable(container, μThLb(), D)
    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        t_gen = dev.thermal_unit
        three_cost = PSY.get_operation_cost(t_gen)
        first_part = three_cost.variable[1]
        second_part = three_cost.variable[2]
        slope = (second_part[1] - first_part[1]) / (second_part[2] - first_part[2]) # $/MWh
        C_th_var = slope * 100.0 # Multiply by 100 to transform to $/pu
        for t in time_steps
            # Written to match latex model
            con[n, t] = JuMP.@constraint(
                jm,
                C_th_var - λUb_var[n, t] + λLb_var[n, t] - μThUb_var[n, t] +
                μThLb_var[n, t] == 0.0
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{OptConditionRenewablePower},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    λUb_var = PSI.get_variable(container, λUb(), D)
    λLb_var = PSI.get_variable(container, λLb(), D)
    μReUb_var = PSI.get_variable(container, μReUb(), D)
    μReLb_var = PSI.get_variable(container, μReLb(), D)
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        # Written to match latex model
        con[n, t] = JuMP.@constraint(
            jm,
            -λUb_var[n, t] + λLb_var[n, t] - μReUb_var[n, t] + μReLb_var[n, t] == 0.0
        )
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{OptConditionBatteryCharge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    Δt_RT = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    λUb_var = PSI.get_variable(container, λUb(), D)
    λLb_var = PSI.get_variable(container, λLb(), D)
    μChUb_var = PSI.get_variable(container, μChUb(), D)
    μChLb_var = PSI.get_variable(container, μChLb(), D)
    γStBalLb_var = PSI.get_variable(container, γStBalLb(), D)
    γStBalUb_var = PSI.get_variable(container, γStBalUb(), D)
    κStCh_var = PSI.get_variable(container, κStCh(), D)

    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        VOM = storage.operation_cost.variable.cost
        η_ch = storage.efficiency.in * Δt_RT
        for t in time_steps
            con[n, t] = JuMP.@constraint(
                jm,
                Δt_RT * VOM + λUb_var[n, t] - λLb_var[n, t] - μChUb_var[n, t] +
                μChLb_var[n, t] +
                η_ch * (-γStBalUb_var[n, t] + γStBalLb_var[n, t] - κStCh_var[n]) == 0.0
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{OptConditionEnergyVariable},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    νStUb_var = PSI.get_variable(container, νStUb(), D)
    νStLb_var = PSI.get_variable(container, νStLb(), D)
    γStBalLb_var = PSI.get_variable(container, γStBalLb(), D)
    γStBalUb_var = PSI.get_variable(container, γStBalUb(), D)
    jm = PSI.get_jump_model(container)
    for n in names
        con[n, 1] = JuMP.@constraint(
            jm,
            γStBalUb_var[n, 1] - γStBalLb_var[n, 1] - νStUb_var[n, 1] + νStLb_var[n, 1] == 0.0
        )
        # Written to match latex model
        for t in time_steps[2:end]
            con[n, t] = JuMP.@constraint(
                jm,
                γStBalUb_var[n, t] - γStBalLb_var[n, t] - γStBalUb_var[n, t - 1] +
                γStBalLb_var[n, t - 1] - νStUb_var[n, t] + νStLb_var[n, t] == 0.0
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{OptConditionBatteryDischarge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    # Temp Fix
    Δt_RT = 1 / 12
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    con = PSI.add_constraints_container!(container, T(), D, names, time_steps)
    λUb_var = PSI.get_variable(container, λUb(), D)
    λLb_var = PSI.get_variable(container, λLb(), D)
    μDsUb_var = PSI.get_variable(container, μDsUb(), D)
    μDsLb_var = PSI.get_variable(container, μDsLb(), D)
    γStBalLb_var = PSI.get_variable(container, γStBalLb(), D)
    γStBalUb_var = PSI.get_variable(container, γStBalUb(), D)
    κStDs_var = PSI.get_variable(container, κStDs(), D)

    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        VOM = storage.operation_cost.variable.cost
        inv_η_ds = Δt_RT / storage.efficiency.out
        # Written to match latex model
        for t in time_steps
            con[n, t] = JuMP.@constraint(
                jm,
                Δt_RT * VOM - λUb_var[n, t] + λLb_var[n, t] - μDsUb_var[n, t] +
                μDsLb_var[n, t] +
                inv_η_ds * (γStBalUb_var[n, t] - γStBalLb_var[n, t] - κStDs_var[n]) ==
                0.0
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessEnergyLimitUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    dual_var = PSI.get_variable(container, νStUb(), D)
    primal_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    k_variable = PSI.get_variable(container, ComplementarySlackVarEnergyLimitUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        e_max_ds = PSY.get_storage_level_limits(storage).max
        for t in time_steps
            assignment_constraint[n, t] =
                JuMP.@constraint(jm, k_variable[n, t] == primal_var[n, t] - e_max_ds)
            sos_constraint[n, t] =
                JuMP.@constraint(jm, [k_variable[n, t], dual_var[n, t]] in JuMP.SOS1())
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessEnergyLimitLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    # Lower Bound is 0.0
    # k_variable = PSI.get_variable(container, xComplementarySlacknessRenewableActivePowerLimitConstraintLb(), D)
    dual_var = PSI.get_variable(container, νStLb(), D)
    primal_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        #assignment_constraint[n, t] =
        # JuMP.@constraint(jm, k_variable[n, t] == primal_var[n, t] - param[t] * multiplier)
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [primal_var[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessEnergyAssetBalanceUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    expression = PSI.get_expression(container, AssetPowerBalance(), D)
    variable = PSI.get_variable(container, ComplementarySlackVarEnergyAssetBalanceUb(), D)
    dual_var = PSI.get_variable(container, λUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        assignment_constraint[n, t] =
            JuMP.@constraint(jm, variable[n, t] == expression[n, t])
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [variable[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessEnergyAssetBalanceLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    expression = PSI.get_expression(container, AssetPowerBalance(), D)
    variable = PSI.get_variable(container, ComplementarySlackVarEnergyAssetBalanceLb(), D)
    dual_var = PSI.get_variable(container, λLb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        assignment_constraint[n, t] =
            JuMP.@constraint(jm, variable[n, t] == expression[n, t])
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [variable[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessThermalOnVariableUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    # Temporary Map for DA to RT
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    dual_var = PSI.get_variable(container, μThUb(), D)
    primal_var = PSI.get_variable(container, ThermalPower(), D)
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    k_variable = PSI.get_variable(container, ComplementarySlackVarThermalOnVariableUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for dev in devices
        tmap = PSY.get_ext(dev)["tmap"]
        n = PSY.get_name(dev)
        thermal = PSY.get_thermal_unit(dev)
        p_max_th = PSY.get_active_power_limits(thermal).max
        for t in time_steps
            assignment_constraint[n, t] = JuMP.@constraint(
                jm,
                k_variable[n, t] == primal_var[n, t] - varon[n, tmap[t]] * p_max_th
            )
            sos_constraint[n, t] =
                JuMP.@constraint(jm, [k_variable[n, t], dual_var[n, t]] in JuMP.SOS1())
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessThermalOnVariableLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    # temp tmap
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    dual_var = PSI.get_variable(container, μThLb(), D)
    primal_var = PSI.get_variable(container, ThermalPower(), D)
    varon = PSI.get_variable(container, PSI.OnVariable(), D)
    k_variable = PSI.get_variable(container, ComplementarySlackVarThermalOnVariableLb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for dev in devices
        tmap = PSY.get_ext(dev)["tmap"]
        n = PSY.get_name(dev)
        thermal = PSY.get_thermal_unit(dev)
        p_min_th = PSY.get_active_power_limits(thermal).min
        for t in time_steps
            assignment_constraint[n, t] = JuMP.@constraint(
                jm,
                k_variable[n, t] == -primal_var[n, t] + varon[n, tmap[t]] * p_min_th
            )
            sos_constraint[n, t] =
                JuMP.@constraint(jm, [k_variable[n, t], dual_var[n, t]] in JuMP.SOS1())
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessRenewableActivePowerLimitConstraintUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    k_variable = PSI.get_variable(
        container,
        ComplementarySlackVarRenewableActivePowerLimitConstraintUb(),
        D,
    )
    dual_var = PSI.get_variable(container, μReUb(), D)
    primal_var = PSI.get_variable(container, RenewablePower(), D)
    re_param_container = PSI.get_parameter(container, RenewablePowerTimeSeries(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for d in devices
        name = PSY.get_name(d)
        multiplier = PSY.get_max_active_power(d.renewable_unit)
        param = PSI.get_parameter_column_refs(re_param_container, name)
        for t in time_steps
            assignment_constraint[name, t] = JuMP.@constraint(
                jm,
                k_variable[name, t] == primal_var[name, t] - param[t] * multiplier
            )
            sos_constraint[name, t] = JuMP.@constraint(
                jm,
                [k_variable[name, t], dual_var[name, t]] in JuMP.SOS1()
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessRenewableActivePowerLimitConstraintLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    # Lower Bound is 0.0
    # k_variable = PSI.get_variable(container, xComplementarySlacknessRenewableActivePowerLimitConstraintLb(), D)
    dual_var = PSI.get_variable(container, μReLb(), D)
    primal_var = PSI.get_variable(container, RenewablePower(), D)
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        #assignment_constraint[n, t] =
        # JuMP.@constraint(jm, k_variable[n, t] == primal_var[n, t] - param[t] * multiplier)
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [primal_var[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryStatusDischargeOnUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    dual_var = PSI.get_variable(container, μDsLb(), D)
    primal_var = PSI.get_variable(container, BatteryDischarge(), D)
    binary = PSI.get_variable(container, BatteryStatus(), D)
    k_variable =
        PSI.get_variable(container, ComplementarySlackVarBatteryStatusDischargeOnUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        p_max_ds = PSY.get_output_active_power_limits(storage).max
        for t in time_steps
            assignment_constraint[n, t] = JuMP.@constraint(
                jm,
                k_variable[n, t] == primal_var[n, t] - p_max_ds * binary[n, t]
            )
            sos_constraint[n, t] =
                JuMP.@constraint(jm, [k_variable[n, t], dual_var[n, t]] in JuMP.SOS1())
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryStatusDischargeOnLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    # Lower Bound is 0.0
    # k_variable = PSI.get_variable(container, xComplementarySlacknessRenewableActivePowerLimitConstraintLb(), D)
    dual_var = PSI.get_variable(container, μDsLb(), D)
    primal_var = PSI.get_variable(container, BatteryDischarge(), D)
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        #assignment_constraint[n, t] =
        # JuMP.@constraint(jm, k_variable[n, t] == primal_var[n, t])
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [primal_var[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryStatusChargeOnUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    dual_var = PSI.get_variable(container, μDsLb(), D)
    primal_var = PSI.get_variable(container, BatteryCharge(), D)
    binary = PSI.get_variable(container, BatteryStatus(), D)
    k_variable =
        PSI.get_variable(container, ComplementarySlackVarBatteryStatusChargeOnUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for dev in devices
        n = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        p_max_ch = PSY.get_input_active_power_limits(storage).max
        for t in time_steps
            assignment_constraint[n, t] = JuMP.@constraint(
                jm,
                k_variable[n, t] == primal_var[n, t] - (1.0 - p_max_ch) * binary[n, t]
            )
            sos_constraint[n, t] =
                JuMP.@constraint(jm, [k_variable[n, t], dual_var[n, t]] in JuMP.SOS1())
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryStatusChargeOnLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    # Lower Bound is 0.0
    # k_variable = PSI.get_variable(container, xComplementarySlacknessRenewableActivePowerLimitConstraintLb(), D)
    dual_var = PSI.get_variable(container, μChLb(), D)
    primal_var = PSI.get_variable(container, BatteryCharge(), D)
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    jm = PSI.get_jump_model(container)
    for n in names, t in time_steps
        #assignment_constraint[n, t] =
        # JuMP.@constraint(jm, k_variable[n, t] == primal_var[n, t])
        sos_constraint[n, t] =
            JuMP.@constraint(jm, [primal_var[n, t], dual_var[n, t]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryBalanceUb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    k_variable = PSI.get_variable(container, ComplementarySlackVarBatteryBalanceUb(), D)
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    dual_var = PSI.get_variable(container, γStBalUb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)
    jm = PSI.get_jump_model(container)
    for ic in initial_conditions
        device = PSI.get_component(ic)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        assignment_constraint[ci_name, 1] = JuMP.@constraint(
            jm,
            k_variable[ci_name, 1] ==
            PSI.get_value(ic) +
            fraction_of_hour * (
                charge_var[ci_name, 1] * efficiency.in -
                (discharge_var[ci_name, 1] / efficiency.out)
            ) - energy_var[ci_name, 1]
        )
        sos_constraint[ci_name, 1] = JuMP.@constraint(
            jm,
            [k_variable[ci_name, 1], dual_var[ci_name, 1]] in JuMP.SOS1()
        )

        for t in time_steps[2:end]
            assignment_constraint[ci_name, 1] = JuMP.@constraint(
                jm,
                k_variable[ci_name, 1] ==
                energy_var[ci_name, t - 1] +
                fraction_of_hour * (
                    charge_var[ci_name, t] * efficiency.in -
                    (discharge_var[ci_name, t] / efficiency.out)
                ) - energy_var[ci_name, t]
            )
            sos_constraint[ci_name, t] = JuMP.@constraint(
                jm,
                [k_variable[ci_name, t], dual_var[ci_name, t]] in JuMP.SOS1()
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{ComplementarySlacknessBatteryBalanceLb},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    resolution = PSI.get_resolution(container)
    fraction_of_hour = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    names = [PSY.get_name(d) for d in devices]
    k_variable = PSI.get_variable(container, ComplementarySlackVarBatteryBalanceLb(), D)
    energy_var = PSI.get_variable(container, PSI.EnergyVariable(), D)
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    discharge_var = PSI.get_variable(container, BatteryDischarge(), D)
    dual_var = PSI.get_variable(container, γStBalLb(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="eq")
    sos_constraint =
        PSI.add_constraints_container!(container, T(), D, names, time_steps, meta="sos")
    initial_conditions = PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), D)
    jm = PSI.get_jump_model(container)
    for ic in initial_conditions
        device = PSI.get_component(ic)
        ci_name = PSY.get_name(device)
        storage = PSY.get_storage(device)
        efficiency = PSY.get_efficiency(storage)
        assignment_constraint[ci_name, 1] = JuMP.@constraint(
            jm,
            k_variable[ci_name, 1] ==
            PSI.get_value(ic) +
            fraction_of_hour * (
                charge_var[ci_name, 1] * efficiency.in -
                (discharge_var[ci_name, 1] / efficiency.out)
            ) - energy_var[ci_name, 1]
        )
        sos_constraint[ci_name, 1] = JuMP.@constraint(
            jm,
            [k_variable[ci_name, 1], dual_var[ci_name, 1]] in JuMP.SOS1()
        )

        for t in time_steps[2:end]
            assignment_constraint[ci_name, 1] = JuMP.@constraint(
                jm,
                k_variable[ci_name, 1] ==
                energy_var[ci_name, t - 1] +
                fraction_of_hour * (
                    charge_var[ci_name, t] * efficiency.in -
                    (discharge_var[ci_name, t] / efficiency.out)
                ) - energy_var[ci_name, t]
            )
            sos_constraint[ci_name, t] = JuMP.@constraint(
                jm,
                [k_variable[ci_name, t], dual_var[ci_name, t]] in JuMP.SOS1()
            )
        end
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ComplentarySlacknessCyclingCharge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    k_variable = PSI.get_variable(container, ComplementarySlackVarCyclingCharge(), D)
    charge_var = PSI.get_variable(container, BatteryCharge(), D)
    dual_var = PSI.get_variable(container, κStCh(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, meta="eq")
    sos_constraint = PSI.add_constraints_container!(container, T(), D, names, meta="sos")
    jm = PSI.get_jump_model(container)
    resolution = PSI.get_resolution(container)
    Δt_RT = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    Cycles = CYCLES_PER_DAY * Δt_RT * length(time_steps) / HOURS_IN_DAY
    for dev in devices
        name = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        _, E_max = PSY.get_storage_level_limits(storage)
        η_ch = storage.efficiency.in * Δt_RT
        assignment_constraint[name] = JuMP.@constraint(
            jm,
            k_variable[name] ==
            sum(charge_var[name, t] * η_ch for t in time_steps) - Cycles * E_max
        )
        sos_constraint[name] =
            JuMP.@constraint(jm, [k_variable[name], dual_var[name]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:ComplentarySlacknessCyclingDischarge},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    k_variable = PSI.get_variable(container, ComplementarySlackVarCyclingDischarge(), D)
    charge_var = PSI.get_variable(container, BatteryDischarge(), D)
    dual_var = PSI.get_variable(container, κStDs(), D)
    assignment_constraint =
        PSI.add_constraints_container!(container, T(), D, names, meta="eq")
    sos_constraint = PSI.add_constraints_container!(container, T(), D, names, meta="sos")
    jm = PSI.get_jump_model(container)
    resolution = PSI.get_resolution(container)
    Δt_RT = Dates.value(Dates.Minute(resolution)) / PSI.MINUTES_IN_HOUR
    Cycles = CYCLES_PER_DAY * Δt_RT * length(time_steps) / HOURS_IN_DAY
    for dev in devices
        name = PSY.get_name(dev)
        storage = PSY.get_storage(dev)
        _, E_max = PSY.get_storage_level_limits(storage)
        η_ch = storage.efficiency.in * Δt_RT
        assignment_constraint[name] = JuMP.@constraint(
            jm,
            k_variable[name] ==
            sum(charge_var[name, t] * η_ch for t in time_steps) - Cycles * E_max
        )
        sos_constraint[name] =
            JuMP.@constraint(jm, [k_variable[name], dual_var[name]] in JuMP.SOS1())
    end
    return
end

function add_constraints!(
    container::PSI.OptimizationContainer,
    T::Type{<:StrongDualityCut},
    devices::U,
    ::W,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: MerchantModelWithReserves,
} where {D <: PSY.HybridSystem}
    time_steps = PSI.get_time_steps(container)
    names = [PSY.get_name(d) for d in devices]
    return
end

function PSI._add_parameters!(
    container::PSI.OptimizationContainer,
    ::T,
    key::PSI.VariableKey{TotalReserve, S},
    model::PSI.ServiceModel{S, W},
    devices::V,
) where {
    S <: PSY.AbstractReserve,
    T <: PSI.VariableValueParameter,
    V <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    W <: PSI.AbstractReservesFormulation,
} where {D <: PSY.Component}
    contributing_devices = PSI.get_contributing_devices(model)
    names = [
        PSY.get_name(device) for
        device in contributing_devices if isa(device, PSY.HybridSystem)
    ]
    isempty(names) && return
    time_steps = PSI.get_time_steps(container)
    parameter_container = PSI.add_param_container!(
        container,
        T(),
        S,
        key,
        names,
        time_steps;
        meta=PSI.get_service_name(model),
    )
    jump_model = PSI.get_jump_model(container)
    for name in names, t in time_steps
        PSI.set_parameter!(parameter_container, jump_model, 0.0, name, t)
    end
    return
end
