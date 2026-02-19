###################################################################
################### Decision Model Variables ######################
###################################################################

# Energy Day-Ahead Bids
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    devices::Vector{PSY.HybridSystem},
    formulation::U,
) where {T <: Union{EnergyDABidOut, EnergyDABidIn}, U <: AbstractHybridFormulation}
    @assert !isempty(devices)
    time_steps = PSY.get_ext(first(devices))["T_da"]
    variable = PSI.add_variable_container!(
        container,
        T(),
        PSY.HybridSystem,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            PSI.get_jump_model(container),
            base_name = "$(T)_HybridSystem_{$(name), $(t)}",
        )
        ub = PSI.get_variable_upper_bound(T(), d, formulation)
        ub !== nothing && JuMP.set_upper_bound(variable[name, t], ub)

        lb = PSI.get_variable_lower_bound(T(), d, formulation)
        lb !== nothing && JuMP.set_lower_bound(variable[name, t], lb)
    end
    return
end

# Day Ahead On Variable
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    devices::Vector{PSY.HybridSystem},
    formulation::U,
) where {
    T <: PSI.OnVariable,
    U <: Union{MerchantHybridEnergyCase, MerchantModelWithReserves},
}
    @assert !isempty(devices)
    time_steps = PSY.get_ext(first(devices))["T_da"]
    variable = PSI.add_variable_container!(
        container,
        T(),
        PSY.HybridSystem,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            PSI.get_jump_model(container),
            base_name = "$(T)_HybridSystem_{$(name), $(t)}",
            binary = true
        )
    end
    return
end

# AS Total Bid for hybrid
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Vector{PSY.HybridSystem},
    formulation::MerchantModelWithReserves,
) where {W <: Union{BidReserveVariableOut, BidReserveVariableIn}}
    @assert !isempty(devices)
    time_steps = PSY.get_ext(first(devices))["T_da"]
    # TODO
    # Best way to create this variable? We need to have all services and its type.
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end

    for service in services
        variable = PSI.add_variable_container!(
            container,
            W(),
            typeof(service),
            PSY.get_name.(devices),
            time_steps;
            meta = PSY.get_name(service),
        )

        for d in devices, t in time_steps
            name = PSY.get_name(d)
            variable[name, t] = JuMP.@variable(
                PSI.get_jump_model(container),
                base_name = "$(W)_$(PSY.get_name(service))_{$(PSY.get_name(d)), $(t)}",
                lower_bound = 0.0
            )
        end
    end

    return
end

# AS Bid for each component and product
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::MerchantHybridCooptimizerCase,
) where {U <: PSY.HybridSystem, W <: ComponentReserveVariableType}
    time_steps = PSI.get_time_steps(container)
    # TODO
    # Best way to create this variable? We need to have all services and its type.
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end

    for service in services
        variable = PSI.add_variable_container!(
            container,
            W(),
            typeof(service),
            PSY.get_name.(devices),
            time_steps;
            meta = PSY.get_name(service),
        )

        for d in devices, t in time_steps
            name = PSY.get_name(d)
            variable[name, t] = JuMP.@variable(
                PSI.get_jump_model(container),
                base_name = "$(W)_$(PSY.get_name(service))_{$(PSY.get_name(d)), $(t)}",
                lower_bound = 0.0
            )
        end
    end

    return
end

# Add variable for dual variables
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::MerchantModelWithReserves,
) where {
    U <: PSY.HybridSystem,
    W <: Union{ComplementarySlackVarCyclingCharge, ComplementarySlackVarCyclingDischarge},
}
    variable = PSI.add_variable_container!(container, W(), U, PSY.get_name.(devices))

    for d in devices
        name = PSY.get_name(d)
        variable[name] = JuMP.@variable(
            PSI.get_jump_model(container),
            base_name = "$(W)_{$(PSY.get_name(d))}",
        )
    end
    return
end

# Add variable for dual variables
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::MerchantModelWithReserves,
) where {U <: PSY.HybridSystem, W <: Union{κStCh, κStDs}}
    variable = PSI.add_variable_container!(container, W(), U, PSY.get_name.(devices))

    for d in devices
        name = PSY.get_name(d)
        variable[name] = JuMP.@variable(
            PSI.get_jump_model(container),
            base_name = "$(W)_{$(PSY.get_name(d))}",
        )
    end
    return
end

# Reserve variable function for components
function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::V,
) where {U <: PSY.HybridSystem, W <: ReserveVariableType, V <: AbstractHybridFormulation}
    time_steps = PSI.get_time_steps(container)
    # TODO
    # Best way to create this variable? We need to have all services and its type.
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end

    for service in services
        variable = PSI.add_variable_container!(
            container,
            W(),
            typeof(service),
            PSY.get_name.(devices),
            time_steps;
            meta = PSY.get_name(service),
        )

        for d in devices, t in time_steps
            name = PSY.get_name(d)
            variable[name, t] = JuMP.@variable(
                PSI.get_jump_model(container),
                base_name = "$(W)_$(PSY.get_name(service))_{$(PSY.get_name(d)), $(t)}",
                lower_bound = 0.0
            )
        end
    end

    return
end

function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::V,
) where {
    U <: PSY.HybridSystem,
    V <: AbstractHybridFormulation,
    W <: Union{TotalReserve, SlackReserveUp, SlackReserveDown},
}
    time_steps = PSI.get_time_steps(container)
    # TODO
    # Best way to create this variable? We need to have all services and its type.
    services = Set()
    for d in devices
        union!(services, PSY.get_services(d))
    end

    variable = PSI.add_variable_container!(
        container,
        W(),
        U,
        PSY.get_name.(devices),
        PSY.get_name.(services),
        time_steps;
    )

    for d in devices
        d_name = PSY.get_name(d)
        for service in services
            s_name = PSY.get_name(service)
            for t in time_steps
                variable[d_name, s_name, t] = JuMP.@variable(
                    PSI.get_jump_model(container),
                    base_name = "$(W)_$(s_name)_{$(d_name), $(t)}",
                    lower_bound = 0.0
                )
            end
        end
    end

    return
end

function PSI.add_variables!(
    container::PSI.OptimizationContainer,
    ::Type{W},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::V,
) where {
    U <: PSY.HybridSystem,
    V <: AbstractHybridFormulation,
    W <: Union{BatteryEnergyShortageVariable, BatteryEnergySurplusVariable},
}
    @assert !isempty(devices)
    variable = PSI.add_variable_container!(container, W(), U, PSY.get_name.(devices))
    for d in devices
        name = PSY.get_name(d)
        variable[name] = JuMP.@variable(
            PSI.get_jump_model(container),
            base_name = "$(W)_{$(PSY.get_name(d))}",
            lower_bound = 0.0
        )
    end
    return
end
