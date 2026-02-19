###################################################################
############# Merchant Only Energy Case Decision Model  ###########
###################################################################

function PSI.build_impl!(decision_model::PSI.DecisionModel{MerchantHybridEnergyCase})
    container = PSI.get_optimization_container(decision_model)
    sys = PSI.get_system(decision_model)
    # Resolution
    Δt_DA = 1.0
    RT_resolution = PSY.get_time_series_resolution(sys)
    sys = PSI.get_system(decision_model)
    Δt_RT = Dates.value(Dates.Minute(RT_resolution)) / PSI.MINUTES_IN_HOUR
    # Initialize Container
    PSI.init_optimization_container!(container, PSI.CopperPlatePowerModel, sys)
    PSI.init_model_store_params!(decision_model)

    # Create Multiple Time Horizons based on ext horizons
    ext = PSY.get_ext(sys)
    dates_da = ext["λ_da_df"][!, "DateTime"]
    dates_rt = ext["λ_rt_df"][!, "DateTime"]
    len_DA = get(ext, "horizon_DA", length(dates_da))
    len_RT = get(ext, "horizon_RT", length(dates_rt))
    T_da = 1:len_DA
    T_rt = 1:len_RT
    container.time_steps = T_rt

    # Map for DA to RT
    tmap = [div(k - 1, Int(length(T_rt) / length(T_da))) + 1 for k in T_rt]

    ###############################
    ######## Parameters ###########
    ###############################

    hybrids = collect(PSY.get_components(PSY.HybridSystem, sys))
    h_names = PSY.get_name.(hybrids)
    for h in hybrids
        PSY.get_ext(h)["T_da"] = T_da
        PSY.get_ext(h)["tmap"] = tmap
    end

    services = Set()
    for d in hybrids
        union!(services, PSY.get_services(d))
    end

    device_model = PSI.get_model(PSI.get_template(decision_model), PSY.HybridSystem)

    ###############################
    ######## Variables ############
    ###############################

    # Add Market variables
    for v in [EnergyDABidOut, EnergyDABidIn]
        PSI.add_variables!(container, v, hybrids, MerchantModelEnergyOnly())
    end

    for v in [EnergyRTBidOut, EnergyRTBidIn]
        PSI.add_variables!(container, v, hybrids, MerchantModelEnergyOnly())
    end

    # Add PCC Variables
    for v in
        [PSI.ActivePowerOutVariable, PSI.ActivePowerInVariable, PSI.ReservationVariable]
        PSI.add_variables!(container, v, hybrids, MerchantModelEnergyOnly())
    end

    # Add internal Asset Variables

    ###############################
    ####### Parameters ############
    ###############################

    _hybrids_with_loads = [d for d in hybrids if PSY.get_electric_load(d) !== nothing]
    _hybrids_with_renewable = [d for d in hybrids if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in hybrids if PSY.get_storage(d) !== nothing]
    _hybrids_with_thermal = [d for d in hybrids if PSY.get_thermal_unit(d) !== nothing]

    if !isempty(_hybrids_with_renewable)
        PSI.add_variables!(
            container,
            RenewablePower,
            _hybrids_with_renewable,
            MerchantModelEnergyOnly(),
        )
        if get(decision_model.ext, "RT", false)
            add_time_series_parameters!(
                container,
                RenewablePowerTimeSeries(),
                _hybrids_with_renewable,
                "RenewableDispatch__max_active_power",
            )
        else
            add_time_series_parameters!(
                container,
                RenewablePowerTimeSeries(),
                _hybrids_with_renewable,
                "RenewableDispatch__max_active_power_da",
            )
        end
    end

    if !isempty(_hybrids_with_loads)
        add_time_series_parameters!(
            container,
            ElectricLoadTimeSeries(),
            _hybrids_with_loads,
        )
        P_ld_container =
            PSI.get_parameter(container, ElectricLoadTimeSeries(), PSY.HybridSystem)
        P_ld_multiplier = PSI.get_parameter_multiplier_array(
            container,
            ElectricLoadTimeSeries(),
            PSY.HybridSystem,
        )
    end

    if !isempty(_hybrids_with_storage)
        for v in [BatteryCharge, BatteryDischarge, PSI.EnergyVariable, BatteryStatus]
            PSI.add_variables!(container, v, hybrids, MerchantModelEnergyOnly())
        end
        PSI.add_initial_condition!(
            container,
            _hybrids_with_storage,
            MerchantModelEnergyOnly(),
            PSI.InitialEnergyLevel(),
        )
        if PSI.get_attribute(device_model, "regularization")
            PSI.add_variables!(
                container,
                ChargeRegularizationVariable,
                _hybrids_with_storage,
                MerchantModelEnergyOnly(),
            )
            PSI.add_variables!(
                container,
                DischargeRegularizationVariable,
                _hybrids_with_storage,
                MerchantModelEnergyOnly(),
            )
            PSI.add_constraints!(
                container,
                ChargeRegularizationConstraint,
                _hybrids_with_storage,
                PSI.get_model(PSI.get_template(decision_model), PSY.HybridSystem),
                PSI.get_network_model(PSI.get_template(decision_model)),
            )
            PSI.add_constraints!(
                container,
                DischargeRegularizationConstraint,
                _hybrids_with_storage,
                PSI.get_model(PSI.get_template(decision_model), PSY.HybridSystem),
                PSI.get_network_model(PSI.get_template(decision_model)),
            )
        end
    end

    if !isempty(_hybrids_with_thermal)
        for v in [ThermalPower, PSI.OnVariable]
            PSI.add_variables!(container, v, hybrids, MerchantModelEnergyOnly())
        end
    end

    ###############################
    ####### Obj. Function #########
    ###############################

    # This function add the parameters for both variables DABidOut and DABidIn
    PSI.add_parameters!(
        container,
        DayAheadEnergyPrice(),
        hybrids,
        MerchantModelEnergyOnly(),
    )

    λ_da_pos = PSI.get_parameter_array(
        container,
        DayAheadEnergyPrice(),
        PSY.HybridSystem,
        "EnergyDABidOut",
    )

    λ_da_neg = PSI.get_parameter_array(
        container,
        DayAheadEnergyPrice(),
        PSY.HybridSystem,
        "EnergyDABidIn",
    )

    # This function add the parameters for both variables RTBidOut and RTBidIn
    PSI.add_parameters!(
        container,
        RealTimeEnergyPrice(),
        hybrids,
        MerchantModelEnergyOnly(),
    )

    λ_rt_pos = PSI.get_parameter_array(
        container,
        RealTimeEnergyPrice(),
        PSY.HybridSystem,
        "EnergyRTBidOut",
    )

    λ_rt_neg = PSI.get_parameter_array(
        container,
        RealTimeEnergyPrice(),
        PSY.HybridSystem,
        "EnergyRTBidIn",
    )

    λ_dart_pos = PSI.get_parameter_array(
        container,
        RealTimeEnergyPrice(),
        PSY.HybridSystem,
        "EnergyDABidOut",
    )

    λ_dart_neg = PSI.get_parameter_array(
        container,
        RealTimeEnergyPrice(),
        PSY.HybridSystem,
        "EnergyDABidIn",
    )

    # DA costs
    eb_da_out = PSI.get_variable(container, EnergyDABidOut(), PSY.HybridSystem)
    eb_da_in = PSI.get_variable(container, EnergyDABidIn(), PSY.HybridSystem)
    if !isempty(_hybrids_with_thermal)
        on_th = PSI.get_variable(container, PSI.OnVariable(), PSY.HybridSystem)
    end

    for t in T_da, dev in hybrids
        name = PSY.get_name(dev)
        lin_cost_da_out = -100.0 * Δt_DA * λ_da_pos[name, t] * eb_da_out[name, t]
        lin_cost_da_in = 100.0 * Δt_DA * λ_da_neg[name, t] * eb_da_in[name, t]
        PSI.add_to_objective_variant_expression!(container, lin_cost_da_out)
        PSI.add_to_objective_variant_expression!(container, lin_cost_da_in)
        if !isnothing(dev.thermal_unit)
            t_gen = dev.thermal_unit
            three_cost = PSY.get_operation_cost(t_gen)
            C_th_fix = three_cost.fixed # $/h
            lin_cost_on_th = Δt_DA * C_th_fix * on_th[name, t]
            PSI.add_to_objective_invariant_expression!(container, lin_cost_on_th)
        end
    end

    # RT costs
    eb_rt_out = PSI.get_variable(container, EnergyRTBidOut(), PSY.HybridSystem)
    eb_rt_in = PSI.get_variable(container, EnergyRTBidIn(), PSY.HybridSystem)
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), PSY.HybridSystem)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), PSY.HybridSystem)
    status = PSI.get_variable(container, PSI.ReservationVariable(), PSY.HybridSystem)
    if !isempty(_hybrids_with_thermal)
        p_th = PSI.get_variable(container, ThermalPower(), PSY.HybridSystem)
    end
    if !isempty(_hybrids_with_renewable)
        p_re = PSI.get_variable(container, RenewablePower(), PSY.HybridSystem)
    end
    if !isempty(_hybrids_with_storage)
        p_ch = PSI.get_variable(container, BatteryCharge(), PSY.HybridSystem)
        p_ds = PSI.get_variable(container, BatteryDischarge(), PSY.HybridSystem)
        e_st = PSI.get_variable(container, PSI.EnergyVariable(), PSY.HybridSystem)
        status_st = PSI.get_variable(container, BatteryStatus(), PSY.HybridSystem)
        if PSI.get_attribute(device_model, "regularization")
            PSI.add_proportional_cost!(
                container,
                ChargeRegularizationVariable(),
                _hybrids_with_storage,
                MerchantModelEnergyOnly(),
            )
            PSI.add_proportional_cost!(
                container,
                DischargeRegularizationVariable(),
                _hybrids_with_storage,
                MerchantModelEnergyOnly(),
            )
        end
    end

    for dev in hybrids
        name = PSY.get_name(dev)
        for t in T_rt
            lin_cost_rt_out = -100.0 * Δt_RT * λ_rt_pos[name, t] * eb_rt_out[name, t]
            lin_cost_rt_in = 100.0 * Δt_RT * λ_rt_neg[name, t] * eb_rt_in[name, t]
            lin_cost_dart_out =
                100.0 * Δt_RT * λ_dart_neg[name, t] * eb_da_out[name, tmap[t]]
            lin_cost_dart_in =
                -100.0 * Δt_RT * λ_dart_pos[name, t] * eb_da_in[name, tmap[t]]
            PSI.add_to_objective_variant_expression!(container, lin_cost_rt_out)
            PSI.add_to_objective_variant_expression!(container, lin_cost_rt_in)
            PSI.add_to_objective_variant_expression!(container, lin_cost_dart_out)
            PSI.add_to_objective_variant_expression!(container, lin_cost_dart_in)
            if !isnothing(dev.thermal_unit)
                t_gen = dev.thermal_unit
                three_cost = PSY.get_operation_cost(t_gen)
                first_part = three_cost.variable[1]
                second_part = three_cost.variable[2]
                slope = (second_part[1] - first_part[1]) / (second_part[2] - first_part[2]) # $/MWh
                C_th_var = slope * 100.0 # Multiply by 100 to transform to $/pu
                lin_cost_p_th = Δt_RT * C_th_var * p_th[name, t]
                PSI.add_to_objective_invariant_expression!(container, lin_cost_p_th)
            end
            if !isnothing(dev.storage)
                VOM = dev.storage.operation_cost.variable.cost
                lin_cost_p_ch = Δt_RT * VOM * p_ch[name, t]
                lin_cost_p_ds = Δt_RT * VOM * p_ds[name, t]
                PSI.add_to_objective_invariant_expression!(container, lin_cost_p_ch)
                PSI.add_to_objective_invariant_expression!(container, lin_cost_p_ds)
            end
        end
    end

    ###############################
    ######## Constraints ##########
    ###############################

    # BidBalance
    constraint_eb_out = PSI.add_constraints_container!(
        container,
        BidBalanceOut(),
        PSY.HybridSystem,
        h_names,
        T_rt,
    )
    constraint_eb_in = PSI.add_constraints_container!(
        container,
        BidBalanceIn(),
        PSY.HybridSystem,
        h_names,
        T_rt,
    )

    constraint_status_bid_in = PSI.add_constraints_container!(
        container,
        StatusInOn(),
        PSY.HybridSystem,
        h_names,
        T_rt,
    )

    constraint_status_bid_out = PSI.add_constraints_container!(
        container,
        StatusOutOn(),
        PSY.HybridSystem,
        h_names,
        T_rt,
    )

    constraint_balance = PSI.add_constraints_container!(
        container,
        EnergyAssetBalance(),
        PSY.HybridSystem,
        h_names,
        T_rt,
    )

    # Thermal
    if !isempty(_hybrids_with_thermal)
        constraint_thermal_on = PSI.add_constraints_container!(
            container,
            ThermalOnVariableUb(),
            PSY.HybridSystem,
            h_names,
            T_rt,
        )

        constraint_thermal_off = PSI.add_constraints_container!(
            container,
            ThermalOnVariableLb(),
            PSY.HybridSystem,
            h_names,
            T_rt,
        )
    end
    # Battery Charging
    if !isempty(_hybrids_with_storage)
        constraint_battery_charging = PSI.add_constraints_container!(
            container,
            BatteryStatusChargeOn(),
            PSY.HybridSystem,
            h_names,
            T_rt,
        )

        constraint_battery_discharging = PSI.add_constraints_container!(
            container,
            BatteryStatusDischargeOn(),
            PSY.HybridSystem,
            h_names,
            T_rt,
        )

        constraint_battery_balance = PSI.add_constraints_container!(
            container,
            BatteryBalance(),
            PSY.HybridSystem,
            h_names,
            T_rt,
        )

        constraint_cycling_charge = PSI.add_constraints_container!(
            container,
            CyclingCharge(),
            PSY.HybridSystem,
            h_names,
        )

        constraint_cycling_discharge = PSI.add_constraints_container!(
            container,
            CyclingDischarge(),
            PSY.HybridSystem,
            h_names,
        )
    end

    if !isempty(_hybrids_with_renewable)
        renewable_upper_bound = PSI.add_constraints_container!(
            container,
            RenewableActivePowerLimitConstraint(),
            PSY.HybridSystem,
            h_names,
            T_rt;
            meta = "ub",
        )

        re_param_container =
            PSI.get_parameter(container, RenewablePowerTimeSeries(), PSY.HybridSystem)
    end
    model = PSI.get_jump_model(container)
    for t in T_rt
        for dev in hybrids
            name = PSY.get_name(dev)
            P_max_pcc = PSY.get_output_active_power_limits(dev).max
            # Market Constraint Bids in/out
            constraint_eb_out[name, t] =
                JuMP.@constraint(model, eb_rt_out[name, t] == p_out[name, t])
            constraint_eb_in[name, t] =
                JuMP.@constraint(model, eb_rt_in[name, t] == p_in[name, t])
            # Status Bids
            constraint_status_bid_in[name, t] = JuMP.@constraint(
                model,
                (1.0 - status[name, t]) * P_max_pcc .>= p_in[name, t]
            )
            constraint_status_bid_out[name, t] =
                JuMP.@constraint(model, status[name, t] * P_max_pcc .>= p_out[name, t])
            # Power Balance
            if !isnothing(dev.electric_load)
                P_ld_array = PSI.get_parameter_column_refs(P_ld_container, name)
            else
                P_ld_array = zeros(length(p_out[name, :]))
            end
            constraint_balance[name, t] = JuMP.@constraint(
                model,
                p_th[name, t] + p_re[name, t] + p_ds[name, t] - p_ch[name, t] -
                P_ld_array[t] - p_out[name, t] + # TODO: Restore P_ld_multiplier
                p_in[name, t] == 0.0
            )
        end
        # Thermal Status
        for dev in _hybrids_with_thermal
            name = PSY.get_name(dev)
            t_gen = dev.thermal_unit
            P_min_th, P_max_th = PSY.get_active_power_limits(t_gen)
            constraint_thermal_on[name, t] =
                JuMP.@constraint(model, p_th[name, t] <= on_th[name, tmap[t]] * P_max_th)
            constraint_thermal_off[name, t] =
                JuMP.@constraint(model, p_th[name, t] >= on_th[name, tmap[t]] * P_min_th)
        end
        for dev in _hybrids_with_renewable
            name = PSY.get_name(dev)
            multiplier = PSY.get_max_active_power(dev.renewable_unit)
            param = PSI.get_parameter_column_refs(re_param_container, name)
            renewable_upper_bound[name, t] = JuMP.@constraint(
                PSI.get_jump_model(container),
                p_re[name, t] <= multiplier * param[t]
            )
        end
    end
    # Storage Conditions
    if !isempty(_hybrids_with_storage)
        initial_conditions =
            PSI.get_initial_condition(container, PSI.InitialEnergyLevel(), PSY.HybridSystem)
        for ic in initial_conditions
            device = PSI.get_component(ic)
            name = PSY.get_name(device)
            storage = PSY.get_storage(device)
            P_ch_max = PSY.get_input_active_power_limits(storage).max
            P_ds_max = PSY.get_output_active_power_limits(storage).max
            η_ch = storage.efficiency.in
            η_ds = storage.efficiency.out
            inv_η_ds = 1.0 / η_ds
            for t in T_rt
                # Battery Constraints
                constraint_battery_charging[name, t] = JuMP.@constraint(
                    model,
                    p_ch[name, t] <= (1.0 - status_st[name, t]) * P_ch_max
                )
                constraint_battery_discharging[name, t] =
                    JuMP.@constraint(model, p_ds[name, t] <= status_st[name, t] * P_ds_max)
                # State of Charge
                if t == 1
                    constraint_battery_balance[name, t] = JuMP.@constraint(
                        model,
                        PSI.get_value(ic) +
                        Δt_RT * (p_ch[name, t] * η_ch - p_ds[name, t] * inv_η_ds) ==
                        e_st[name, t]
                    )
                else
                    constraint_battery_balance[name, t] = JuMP.@constraint(
                        model,
                        e_st[name, t - 1] +
                        Δt_RT * (p_ch[name, t] * η_ch - p_ds[name, t] * inv_η_ds) ==
                        e_st[name, t]
                    )
                end
            end
        end

        # Cycling Constraints
        # Same Cycles for each Storage

        Cycles = CYCLES_PER_DAY * Δt_RT * length(T_rt) / HOURS_IN_DAY
        for dev in _hybrids_with_storage
            name = PSY.get_name(dev)
            storage = dev.storage
            η_ch = storage.efficiency.in
            η_ds = storage.efficiency.out
            inv_η_ds = 1.0 / η_ds
            E_min, E_max = PSY.get_state_of_charge_limits(storage)
            constraint_cycling_charge[name] = JuMP.@constraint(
                model,
                inv_η_ds * Δt_RT * sum(p_ds[name, t] for t in T_rt) <= Cycles * E_max
            )
            constraint_cycling_discharge[name] = JuMP.@constraint(
                model,
                η_ch * Δt_RT * sum(p_ch[name, t] for t in T_rt) <= Cycles * E_max
            )
        end
    end

    PSI.add_feedforward_arguments!(container, device_model, hybrids)
    PSI.update_objective_function!(container)
    PSI.serialize_metadata!(container, PSI.get_output_dir(decision_model))
    return
end
