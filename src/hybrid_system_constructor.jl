
###################################################################
########## Argument Constructor for Hybrid Energy Only  ###########
###################################################################
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ArgumentConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {T <: PSY.HybridSystem, D <: HybridEnergyOnlyDispatch, S <: PM.AbstractPowerModel}
    devices = PSI.get_available_components(model, sys)
    # Add Common Variables
    PSI.add_variables!(container, PSI.ActivePowerOutVariable, devices, D())
    PSI.add_variables!(container, PSI.ActivePowerInVariable, devices, D())
    PSI.add_variables!(container, PSI.ReservationVariable, devices, D())

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    if PSI.has_service_model(model)
        error("Services are not supported by $D")
    end

    ### Add Component Variables ###

    _hybrids_with_thermal = [d for d in devices if PSY.get_thermal_unit(d) !== nothing]
    _hybrids_with_renewable = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in devices if PSY.get_storage(d) !== nothing]
    _hybrids_with_loads = [d for d in devices if PSY.get_electric_load(d) !== nothing]

    # Thermal
    if !isempty(_hybrids_with_thermal)
        PSI.add_variables!(container, ThermalPower, _hybrids_with_thermal, D())
        PSI.add_variables!(container, PSI.OnVariable, _hybrids_with_thermal, D())
    end

    # Renewable
    if !isempty(_hybrids_with_renewable)
        PSI.add_variables!(container, RenewablePower, _hybrids_with_renewable, D())
    end

    # Storage
    if !isempty(_hybrids_with_storage)
        PSI.add_variables!(container, BatteryCharge, _hybrids_with_storage, D())
        PSI.add_variables!(container, BatteryDischarge, _hybrids_with_storage, D())
        PSI.add_variables!(container, PSI.EnergyVariable, _hybrids_with_storage, D())
        PSI.add_variables!(container, BatteryStatus, _hybrids_with_storage, D())

        PSI.add_variables!(container, CyclingChargeUsage, _hybrids_with_storage, D())

        PSI.add_variables!(container, CyclingDischargeUsage, _hybrids_with_storage, D())

        if PSI.get_attribute(model, "energy_target")
            PSI.add_variables!(
                container,
                BatteryEnergyShortageVariable,
                _hybrids_with_storage,
                D(),
            )
            PSI.add_variables!(
                container,
                BatteryEnergySurplusVariable,
                _hybrids_with_storage,
                D(),
            )
        end

        if PSI.get_attribute(model, "cycling")
            #=
            if PSI.built_for_recurrent_solves(container)
                PSI.add_parameters!(
                    container,
                    CyclingChargeLimitParameter,
                    _hybrids_with_storage,
                    model,
                )
                PSI.add_parameters!(
                    container,
                    CyclingDischargeLimitParameter,
                    _hybrids_with_storage,
                    model,
                )
            end
            =#
        end

        if PSI.get_attribute(model, "regularization")
            PSI.add_variables!(container, ChargeRegularizationVariable, devices, D())
            PSI.add_variables!(container, DischargeRegularizationVariable, devices, D())
        end

        PSI.initial_conditions!(container, _hybrids_with_storage, D())
    end

    ### Add Parameters ###
    if !isempty(_hybrids_with_renewable)
        PSI.add_parameters!(
            container,
            RenewablePowerTimeSeries,
            _hybrids_with_renewable,
            model,
        )
    end
    if !isempty(_hybrids_with_loads)
        PSI.add_parameters!(container, ElectricLoadTimeSeries, _hybrids_with_loads, model)
    end

    PSI.add_feedforward_arguments!(container, model, devices)

    ### Objective Function ###
    PSI.objective_function!(container, devices, model, network_model)
    return
end

###################################################################
########## Model Constructor for Hybrid Energy Only  ##############
###################################################################
### ModelConstruct Hybrid Only Energy ###
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ModelConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {
    T <: PSY.HybridSystem,
    D <: HybridEnergyOnlyDispatch,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSI.get_available_components(model, sys)

    # Constraints
    PSI.add_constraints!(
        container,
        PSI.InputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    PSI.add_constraints!(
        container,
        PSI.OutputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    # Binary Hybrid Output or Input
    PSI.add_constraints!(container, StatusOutOn, devices, model, network_model)

    PSI.add_constraints!(container, StatusInOn, devices, model, network_model)

    # Energy Asset Balance
    PSI.add_constraints!(container, EnergyAssetBalance, devices, model, network_model)

    ### Add Component Constraints ###
    _hybrids_with_thermal = [d for d in devices if PSY.get_thermal_unit(d) !== nothing]
    _hybrids_with_renewable = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in devices if PSY.get_storage(d) !== nothing]

    # Thermal
    if !isempty(_hybrids_with_thermal)
        PSI.add_constraints!(
            container,
            ThermalOnVariableUb,
            _hybrids_with_thermal,
            model,
            network_model,
        )
        PSI.add_constraints!(
            container,
            ThermalOnVariableLb,
            _hybrids_with_thermal,
            model,
            network_model,
        )
    end

    # Storage
    if !isempty(_hybrids_with_storage)
        PSI.add_constraints!(
            container,
            BatteryStatusChargeOn,
            _hybrids_with_storage,
            model,
            network_model,
        )
        PSI.add_constraints!(
            container,
            BatteryStatusDischargeOn,
            _hybrids_with_storage,
            model,
            network_model,
        )
        PSI.add_constraints!(
            container,
            BatteryBalance,
            _hybrids_with_storage,
            model,
            network_model,
        )
        if PSI.get_attribute(model, "cycling")
            PSI.add_constraints!(
                container,
                CyclingCharge,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                CyclingDischarge,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
        if PSI.get_attribute(model, "energy_target")
            PSI.add_constraints!(
                container,
                StateofChargeTargetConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end

        if PSI.get_attribute(model, "regularization")
            PSI.add_constraints!(
                container,
                ChargeRegularizationConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                DischargeRegularizationConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
    end

    # Renewable
    if !isempty(_hybrids_with_renewable)
        PSI.add_constraints!(
            container,
            RenewableActivePowerLimitConstraint,
            _hybrids_with_renewable,
            model,
            network_model,
        )
    end

    PSI.add_feedforward_constraints!(container, model, devices)
    return
end

###################################################################
########## Argument Constructor for Hybrid with Reserves  #########
###################################################################
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ArgumentConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {T <: PSY.HybridSystem, D <: HybridDispatchWithReserves, S <: PM.AbstractPowerModel}
    devices = PSI.get_available_components(model, sys)
    device_names = PSY.get_name.(devices)
    service_names = PSY.get_name.(PSY.get_components(PSY.Reserve, sys))
    time_steps = PSI.get_time_steps(container)
    # Add Common Variables
    PSI.add_variables!(container, PSI.ActivePowerOutVariable, devices, D())
    PSI.add_variables!(container, PSI.ActivePowerInVariable, devices, D())
    PSI.add_variables!(container, PSI.ReservationVariable, devices, D())

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    ### Add Component Variables ###

    _hybrids_with_thermal = [d for d in devices if PSY.get_thermal_unit(d) !== nothing]
    _hybrids_with_renewable = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in devices if PSY.get_storage(d) !== nothing]
    _hybrids_with_loads = [d for d in devices if PSY.get_electric_load(d) !== nothing]

    # Add hybrid system reserve variables and reserve expressions
    if PSI.has_service_model(model)
        PSI.add_variables!(container, ReserveVariableOut, devices, D())
        PSI.add_variables!(container, ReserveVariableIn, devices, D())

        # Ancillary Services Balance Expressions (Out/In Up/Down)
        PSI.lazy_container_addition!(
            container,
            TotalReserveOutUpExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.get_expression(container, TotalReserveOutUpExpression(), PSY.HybridSystem)

        PSI.lazy_container_addition!(
            container,
            TotalReserveOutDownExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.lazy_container_addition!(
            container,
            TotalReserveInUpExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.lazy_container_addition!(
            container,
            TotalReserveInDownExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        # Expression for Total Reserve Out (Up/Down)
        PSI.add_to_expression!(
            container,
            TotalReserveOutUpExpression,
            ReserveVariableOut,
            devices,
            model,
            network_model,
        )

        PSI.add_to_expression!(
            container,
            TotalReserveOutDownExpression,
            ReserveVariableOut,
            devices,
            model,
            network_model,
        )

        # Expression for Total Reserve In (Up/Down)
        PSI.add_to_expression!(
            container,
            TotalReserveInUpExpression,
            ReserveVariableIn,
            devices,
            model,
            network_model,
        )

        PSI.add_to_expression!(
            container,
            TotalReserveInDownExpression,
            ReserveVariableIn,
            devices,
            model,
            network_model,
        )

        # Add Served Reserve Up/Down Out/In Expression
        PSI.lazy_container_addition!(
            container,
            ServedReserveOutUpExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.lazy_container_addition!(
            container,
            ServedReserveOutDownExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.lazy_container_addition!(
            container,
            ServedReserveInUpExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        PSI.lazy_container_addition!(
            container,
            ServedReserveInDownExpression(),
            T,
            PSY.get_name.(devices),
            time_steps,
        )

        # Out Total Up
        add_to_expression!(
            container,
            ServedReserveOutUpExpression,
            ReserveVariableOut,
            devices,
            D(),
            time_steps,
        )

        # Out Total Down
        add_to_expression!(
            container,
            ServedReserveOutDownExpression,
            ReserveVariableOut,
            devices,
            D(),
            time_steps,
        )

        # In Total Up
        add_to_expression!(
            container,
            ServedReserveInUpExpression,
            ReserveVariableIn,
            devices,
            D(),
            time_steps,
        )

        # In Total Down
        add_to_expression!(
            container,
            ServedReserveInDownExpression,
            ReserveVariableIn,
            devices,
            D(),
            time_steps,
        )
    end

    # Thermal
    if !isempty(_hybrids_with_thermal)
        # Physical Variables
        PSI.add_variables!(container, ThermalPower, _hybrids_with_thermal, D())
        PSI.add_variables!(container, PSI.OnVariable, _hybrids_with_thermal, D())
        # Add reserve variables and expressions for thermal unit
        if PSI.has_service_model(model)
            PSI.add_variables!(
                container,
                ThermalReserveVariable,
                _hybrids_with_thermal,
                D(),
            )

            # Add reserve variables and expressions for thermal unit
            PSI.lazy_container_addition!(
                container,
                ThermalReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_thermal),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                ThermalReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_thermal),
                time_steps,
            )

            # add to expression thermal up reserve
            PSI.add_to_expression!(
                container,
                ThermalReserveUpExpression,
                ThermalReserveVariable,
                _hybrids_with_thermal,
                model,
                network_model,
            )

            # add to expression thermal down reserve
            PSI.add_to_expression!(
                container,
                ThermalReserveDownExpression,
                ThermalReserveVariable,
                _hybrids_with_thermal,
                model,
                network_model,
            )

            # Add served reserve variables and expressions
            PSI.lazy_container_addition!(
                container,
                ThermalServedReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_thermal),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                ThermalServedReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_thermal),
                time_steps,
            )

            # add to expression thermal up served reserve
            PSI.add_to_expression!(
                container,
                ThermalServedReserveUpExpression,
                ThermalReserveVariable,
                _hybrids_with_thermal,
                model,
                network_model,
            )

            # add to expression thermal down served reserve
            PSI.add_to_expression!(
                container,
                ThermalServedReserveDownExpression,
                ThermalReserveVariable,
                _hybrids_with_thermal,
                model,
                network_model,
            )
        end
    end

    # Renewable
    if !isempty(_hybrids_with_renewable)
        # Physical Variables
        PSI.add_variables!(container, RenewablePower, _hybrids_with_renewable, D())
        # Add reserve variables and expressions for renewable unit
        if PSI.has_service_model(model)
            PSI.add_variables!(
                container,
                RenewableReserveVariable,
                _hybrids_with_renewable,
                D(),
            )

            # Create renewable total up reserves
            PSI.lazy_container_addition!(
                container,
                RenewableReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_renewable),
                time_steps,
            )

            # Create renewable total down reserves
            PSI.lazy_container_addition!(
                container,
                RenewableReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_renewable),
                time_steps,
            )

            # add to expression renewable up reserve
            PSI.add_to_expression!(
                container,
                RenewableReserveUpExpression,
                RenewableReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )

            # add to expression renewable down reserve
            PSI.add_to_expression!(
                container,
                RenewableReserveDownExpression,
                RenewableReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )

            # Create renewable served up reserves
            PSI.lazy_container_addition!(
                container,
                RenewableServedReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_renewable),
                time_steps,
            )

            # Create renewable served down reserves
            PSI.lazy_container_addition!(
                container,
                RenewableServedReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_renewable),
                time_steps,
            )

            # add to expression renewable up reserve
            PSI.add_to_expression!(
                container,
                RenewableServedReserveUpExpression,
                RenewableReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )

            # add to expression renewable down reserve
            PSI.add_to_expression!(
                container,
                RenewableServedReserveDownExpression,
                RenewableReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )
        end
    end

    # Storage
    if !isempty(_hybrids_with_storage)
        # Physical Variables
        PSI.add_variables!(container, BatteryCharge, _hybrids_with_storage, D())
        PSI.add_variables!(container, BatteryDischarge, _hybrids_with_storage, D())
        PSI.add_variables!(container, PSI.EnergyVariable, _hybrids_with_storage, D())
        PSI.add_variables!(container, BatteryStatus, _hybrids_with_storage, D())

        if PSI.get_attribute(model, "energy_target")
            PSI.add_variables!(
                container,
                BatteryEnergyShortageVariable,
                _hybrids_with_storage,
                D(),
            )
            PSI.add_variables!(
                container,
                BatteryEnergySurplusVariable,
                _hybrids_with_storage,
                D(),
            )
        end

        PSI.add_variables!(container, CyclingChargeUsage, _hybrids_with_storage, D())
        PSI.add_variables!(container, CyclingDischargeUsage, _hybrids_with_storage, D())
        if PSI.get_attribute(model, "cycling")
            #=
            if PSI.built_for_recurrent_solves(container)
                PSI.add_parameters!(
                    container,
                    CyclingChargeLimitParameter,
                    _hybrids_with_storage,
                    model,
                )
                PSI.add_parameters!(
                    container,
                    CyclingDischargeLimitParameter,
                    _hybrids_with_storage,
                    model,
                )
            end
            =#
        end

        if PSI.get_attribute(model, "regularization")
            PSI.add_variables!(container, ChargeRegularizationVariable, devices, D())
            PSI.add_variables!(container, DischargeRegularizationVariable, devices, D())
        end

        PSI.add_feedforward_arguments!(container, model, collect(devices))

        # Add reserve variables and expressions for storage unit
        if PSI.has_service_model(model)
            # Reserve Variables
            PSI.add_variables!(
                container,
                ChargingReserveVariable,
                _hybrids_with_storage,
                D(),
            )
            PSI.add_variables!(
                container,
                DischargingReserveVariable,
                _hybrids_with_storage,
                D(),
            )

            # Add reserve variables and expressions for charging unit
            PSI.lazy_container_addition!(
                container,
                ChargeReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                ChargeReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.add_to_expression!(
                container,
                ChargeReserveUpExpression,
                ChargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            PSI.add_to_expression!(
                container,
                ChargeReserveDownExpression,
                ChargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            # Add reserve variables and expressions for discharging unit
            PSI.lazy_container_addition!(
                container,
                DischargeReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                DischargeReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.add_to_expression!(
                container,
                DischargeReserveUpExpression,
                DischargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            PSI.add_to_expression!(
                container,
                DischargeReserveDownExpression,
                DischargingReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )

            ## Served ##
            # Add served reserve variables and expressions for charging unit
            PSI.lazy_container_addition!(
                container,
                ChargeServedReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                ChargeServedReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.add_to_expression!(
                container,
                ChargeServedReserveUpExpression,
                ChargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            PSI.add_to_expression!(
                container,
                ChargeServedReserveDownExpression,
                ChargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            # Add served reserve variables and expressions for discharging unit
            PSI.lazy_container_addition!(
                container,
                DischargeServedReserveUpExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.lazy_container_addition!(
                container,
                DischargeServedReserveDownExpression(),
                T,
                PSY.get_name.(_hybrids_with_storage),
                time_steps,
            )

            PSI.add_to_expression!(
                container,
                DischargeServedReserveUpExpression,
                DischargingReserveVariable,
                _hybrids_with_storage,
                model,
                network_model,
            )

            PSI.add_to_expression!(
                container,
                DischargeServedReserveDownExpression,
                DischargingReserveVariable,
                _hybrids_with_renewable,
                model,
                network_model,
            )
        end
        PSI.initial_conditions!(container, _hybrids_with_storage, D())
    end

    ### Add Parameters ###
    if !isempty(_hybrids_with_renewable)
        PSI.add_parameters!(
            container,
            RenewablePowerTimeSeries,
            _hybrids_with_renewable,
            model,
        )
    end
    if !isempty(_hybrids_with_loads)
        PSI.add_parameters!(container, ElectricLoadTimeSeries, _hybrids_with_loads, model)
    end

    ### Objective Function ###
    PSI.objective_function!(container, devices, model, network_model)
    return
end

###################################################################
########### Model Constructor for Hybrid with Reserves  ###########
###################################################################
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ModelConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {
    T <: PSY.HybridSystem,
    D <: HybridDispatchWithReserves,
    S <: PM.AbstractActivePowerModel,
}
    devices = PSY.get_available_components(T, sys)

    # Constraints
    PSI.add_constraints!(
        container,
        PSI.InputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    PSI.add_constraints!(
        container,
        PSI.OutputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    # Binary Hybrid Output or Input
    PSI.add_constraints!(container, StatusOutOn, devices, model, network_model)

    PSI.add_constraints!(container, StatusInOn, devices, model, network_model)

    # Energy Asset Balance
    PSI.add_constraints!(container, EnergyAssetBalance, devices, model, network_model)

    ### Add Component Constraints ###
    _hybrids_with_thermal = [d for d in devices if PSY.get_thermal_unit(d) !== nothing]
    _hybrids_with_renewable = [d for d in devices if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in devices if PSY.get_storage(d) !== nothing]

    # Thermal
    if !isempty(_hybrids_with_thermal)
        if PSI.has_service_model(model)
            PSI.add_constraints!(
                container,
                ThermalReserveLimit,
                _hybrids_with_thermal,
                model,
                network_model,
            )
        else
            PSI.add_constraints!(
                container,
                ThermalOnVariableUb,
                _hybrids_with_thermal,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                ThermalOnVariableLb,
                _hybrids_with_thermal,
                model,
                network_model,
            )
        end
    end

    # Storage
    if !isempty(_hybrids_with_storage)
        PSI.add_constraints!(
            container,
            BatteryBalance,
            _hybrids_with_storage,
            model,
            network_model,
        )
        if PSI.get_attribute(model, "cycling")
            PSI.add_constraints!(
                container,
                CyclingCharge,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                CyclingDischarge,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
        if PSI.get_attribute(model, "energy_target")
            PSI.add_constraints!(
                container,
                StateofChargeTargetConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
        if PSI.get_attribute(model, "regularization")
            PSI.add_constraints!(
                container,
                ChargeRegularizationConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                DischargeRegularizationConstraint,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
        if PSI.has_service_model(model)
            # TODO FIX: We need to ensure that when creating the constraints the each device has only its own services
            services = Set()
            for d in devices
                union!(services, PSY.get_services(d))
            end
            for service in services
                PSI.add_constraints!(
                    container,
                    ReserveCoverageConstraint,
                    _hybrids_with_storage,
                    service,
                    model,
                    network_model,
                )
                PSI.add_constraints!(
                    container,
                    ReserveCoverageConstraintEndOfPeriod,
                    _hybrids_with_storage,
                    service,
                    model,
                    network_model,
                )
            end
            PSI.add_constraints!(
                container,
                ChargingReservePowerLimit,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                DischargingReservePowerLimit,
                _hybrids_with_storage,
                model,
                network_model,
            )
        else
            PSI.add_constraints!(
                container,
                BatteryStatusChargeOn,
                _hybrids_with_storage,
                model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                BatteryStatusDischargeOn,
                _hybrids_with_storage,
                model,
                network_model,
            )
        end
    end

    # Renewable
    if !isempty(_hybrids_with_renewable)
        PSI.add_constraints!(
            container,
            RenewableActivePowerLimitConstraint,
            _hybrids_with_renewable,
            model,
            network_model,
        )
        if PSI.has_service_model(model)
            PSI.add_constraints!(
                container,
                RenewableReserveLimit,
                _hybrids_with_renewable,
                model,
                network_model,
            )
        end
    end

    if PSI.has_service_model(model)
        PSI.add_constraints!(
            container,
            HybridReserveAssignmentConstraint,
            devices,
            model,
            network_model,
        )

        PSI.add_constraints!(container, ReserveBalance, devices, model, network_model)
    end

    PSI.add_feedforward_constraints!(container, model, devices)
    return
end

###################################################################
######## Argument Constructor for FixedDA with Reserves  ##########
###################################################################
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ArgumentConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {T <: PSY.HybridSystem, D <: HybridFixedDA, S <: PM.AbstractPowerModel}
    devices = PSI.get_available_components(model, sys)
    # Add Common Variables
    PSI.add_variables!(container, PSI.ActivePowerOutVariable, devices, D())
    PSI.add_variables!(container, PSI.ActivePowerInVariable, devices, D())

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )

    PSI.add_to_expression!(
        container,
        PSI.ActivePowerBalance,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    if PSI.has_service_model(model)
        PSI.add_variables!(container, TotalReserve, devices, D())
    end

    PSI.add_feedforward_arguments!(container, model, devices)

    return
end

###################################################################
########## Model Constructor for FixedDA with Reserves  ###########
###################################################################
function PSI.construct_device!(
    container::PSI.OptimizationContainer,
    sys::PSY.System,
    ::PSI.ModelConstructStage,
    model::PSI.DeviceModel{T, D},
    network_model::PSI.NetworkModel{S},
) where {T <: PSY.HybridSystem, D <: HybridFixedDA, S <: PM.AbstractActivePowerModel}
    devices = PSI.get_available_components(model, sys)

    # Constraints
    PSI.add_constraints!(
        container,
        PSI.InputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerInVariable,
        devices,
        model,
        network_model,
    )
    PSI.add_constraints!(
        container,
        PSI.OutputActivePowerVariableLimitsConstraint,
        PSI.ActivePowerOutVariable,
        devices,
        model,
        network_model,
    )

    if PSI.has_service_model(model)
        PSI.add_constraints!(
            container,
            HybridReserveAssignmentConstraint,
            devices,
            model,
            network_model,
        )
    end

    return
end
