
###################################################################
########## Merchant Energy + Reserves Case Decision Model  ########
###################################################################

function PSI.build_impl!(decision_model::PSI.DecisionModel{MerchantHybridCooptimizerCase})
    container = PSI.get_optimization_container(decision_model)
    model = container.JuMPmodel
    sys = PSI.get_system(decision_model)
    T = PSY.HybridSystem
    # Resolution
    RT_resolution = first(PSY.get_time_series_resolutions(sys))
    Δt_DA = 1.0
    Δt_RT = Dates.value(Dates.Minute(RT_resolution)) / PSI.MINUTES_IN_HOUR
    # Initialize Container
    PSI.init_optimization_container!(
        container,
        PSI.get_network_model(PSI.get_template(decision_model)),
        sys,
    )
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
    time_steps = T_rt

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
    for h in hybrids
        union!(services, PSY.get_services(h))
    end

    if !isempty(services)
        PSI.add_variables!(container, TotalReserve, hybrids, MerchantModelWithReserves())
        if len_DA == 24
            PSI.add_variables!(
                container,
                SlackReserveUp,
                hybrids,
                MerchantModelWithReserves(),
            )
            PSI.add_variables!(
                container,
                SlackReserveDown,
                hybrids,
                MerchantModelWithReserves(),
            )
        end
    end

    device_model = PSI.get_model(PSI.get_template(decision_model), PSY.HybridSystem)
    device_formulation =
        device_model === nothing ? MerchantModelWithReserves : PSI.get_formulation(device_model)
    network_model = PSI.get_network_model(PSI.get_template(decision_model))

    ###############################
    ######## Variables ############
    ###############################

    # Add Market variables
    for v in [EnergyDABidOut, EnergyDABidIn]
        PSI.add_variables!(container, v, hybrids, MerchantModelWithReserves())
    end

    for v in [EnergyRTBidOut, EnergyRTBidIn]
        PSI.add_variables!(container, v, hybrids, MerchantModelWithReserves())
    end

    # Add PCC Variables
    for v in
        [PSI.ActivePowerOutVariable, PSI.ActivePowerInVariable, PSI.ReservationVariable]
        PSI.add_variables!(container, v, hybrids, MerchantModelWithReserves())
    end

    # Add Reserve Variables
    for v in [BidReserveVariableOut, BidReserveVariableIn]
        PSI.add_variables!(container, v, hybrids, MerchantModelWithReserves())
    end

    # Add Reserve Up/Down Out/In Expression
    PSI.lazy_container_addition!(
        container,
        TotalReserveOutUpExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        TotalReserveOutDownExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        TotalReserveInUpExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        TotalReserveInDownExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    # Out Total Up
    add_to_expression!(
        container,
        TotalReserveOutUpExpression,
        BidReserveVariableOut,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # Out Total Down
    add_to_expression!(
        container,
        TotalReserveOutDownExpression,
        BidReserveVariableOut,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # In Total Up
    add_to_expression!(
        container,
        TotalReserveInUpExpression,
        BidReserveVariableIn,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # In Total Down
    add_to_expression!(
        container,
        TotalReserveInDownExpression,
        BidReserveVariableIn,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # Add Served Reserve Up/Down Out/In Expression
    PSI.lazy_container_addition!(
        container,
        ServedReserveOutUpExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        ServedReserveOutDownExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        ServedReserveInUpExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    PSI.lazy_container_addition!(
        container,
        ServedReserveInDownExpression(),
        T,
        PSY.get_name.(hybrids),
        T_da,
    )

    # Out Total Up
    add_to_expression!(
        container,
        ServedReserveOutUpExpression,
        BidReserveVariableOut,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # Out Total Down
    add_to_expression!(
        container,
        ServedReserveOutDownExpression,
        BidReserveVariableOut,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # In Total Up
    add_to_expression!(
        container,
        ServedReserveInUpExpression,
        BidReserveVariableIn,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # In Total Down
    add_to_expression!(
        container,
        ServedReserveInDownExpression,
        BidReserveVariableIn,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    ###############################
    ####### Parameters ############
    ###############################

    _hybrids_with_loads = [d for d in hybrids if PSY.get_electric_load(d) !== nothing]
    _hybrids_with_renewable = [d for d in hybrids if PSY.get_renewable_unit(d) !== nothing]
    _hybrids_with_storage = [d for d in hybrids if PSY.get_storage(d) !== nothing]
    _hybrids_with_thermal = [d for d in hybrids if PSY.get_thermal_unit(d) !== nothing]

    ## Renewable Variables and Expressions ##
    if !isempty(_hybrids_with_renewable)
        PSI.add_variables!(
            container,
            RenewablePower,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
        )
        PSI.add_variables!(
            container,
            EnergyRenewableBid,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
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
        PSI.add_variables!(
            container,
            RenewableReserveVariable,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
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

        add_to_expression_componentreserveup!(
            container,
            RenewableReserveUpExpression,
            RenewableReserveVariable,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
            time_steps,
        )

        add_to_expression_componentreservedown!(
            container,
            RenewableReserveDownExpression,
            RenewableReserveVariable,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
            time_steps,
        )

        # Create served renewable total up reserves
        PSI.lazy_container_addition!(
            container,
            RenewableServedReserveUpExpression(),
            T,
            PSY.get_name.(_hybrids_with_renewable),
            time_steps,
        )

        # Create served renewable total down reserves
        PSI.lazy_container_addition!(
            container,
            RenewableServedReserveDownExpression(),
            T,
            PSY.get_name.(_hybrids_with_renewable),
            time_steps,
        )

        add_to_expression_componentservedreserveup!(
            container,
            RenewableServedReserveUpExpression,
            RenewableReserveVariable,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
            time_steps,
        )

        add_to_expression_componentservedreservedown!(
            container,
            RenewableServedReserveDownExpression,
            RenewableReserveVariable,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
            time_steps,
        )
    end

    ## Load Variables and Expressions ##
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

    ## Storage Variables and Expressions ##
    if !isempty(_hybrids_with_storage)
        for v in [
            BatteryCharge,
            BatteryDischarge,
            PSI.EnergyVariable,
            BatteryStatus,
            ChargingReserveVariable,
            DischargingReserveVariable,
            EnergyBatteryChargeBid,
            EnergyBatteryDischargeBid,
            CyclingChargeUsage,
            CyclingDischargeUsage,
        ]
            PSI.add_variables!(
                container,
                v,
                _hybrids_with_storage,
                MerchantModelWithReserves(),
            )
        end
        PSI.add_initial_condition!(
            container,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
            PSI.InitialEnergyLevel(),
        )

        # Add reserve expressions for charging unit
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

        add_to_expression_componentreserveup!(
            container,
            ChargeReserveUpExpression,
            ChargingReserveVariable,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
            time_steps,
        )

        add_to_expression_componentreservedown!(
            container,
            ChargeReserveDownExpression,
            ChargingReserveVariable,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
            time_steps,
        )

        # Add served reserve expressions for charging unit
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

        add_to_expression_componentservedreserveup!(
            container,
            ChargeServedReserveUpExpression,
            ChargingReserveVariable,
            _hybrids_with_storage,
            device_formulation(),
            time_steps,
        )

        add_to_expression_componentservedreservedown!(
            container,
            ChargeServedReserveDownExpression,
            ChargingReserveVariable,
            _hybrids_with_storage,
            device_formulation(),
            time_steps,
        )

        # Add reserve expressions for discharging unit
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

        add_to_expression_componentreserveup!(
            container,
            DischargeReserveUpExpression,
            DischargingReserveVariable,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
            time_steps,
        )

        add_to_expression_componentreservedown!(
            container,
            DischargeReserveDownExpression,
            DischargingReserveVariable,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
            time_steps,
        )

        # Add served reserve expressions for discharging unit
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

        add_to_expression_componentservedreserveup!(
            container,
            DischargeServedReserveUpExpression,
            DischargingReserveVariable,
            _hybrids_with_storage,
            device_formulation(),
            time_steps,
        )
        add_to_expression_componentservedreservedown!(
            container,
            DischargeServedReserveDownExpression,
            DischargingReserveVariable,
            _hybrids_with_storage,
            device_formulation(),
            time_steps,
        )

        # Regularization terms
        if PSI.get_attribute(device_model, "regularization")
            PSI.add_variables!(
                container,
                ChargeRegularizationVariable,
                _hybrids_with_storage,
                MerchantModelWithReserves(),
            )
            PSI.add_variables!(
                container,
                DischargeRegularizationVariable,
                _hybrids_with_storage,
                MerchantModelWithReserves(),
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
        for v in [ThermalPower, PSI.OnVariable, ThermalReserveVariable, EnergyThermalBid]
            PSI.add_variables!(
                container,
                v,
                _hybrids_with_thermal,
                MerchantModelWithReserves(),
            )
        end
        # Add Expressions for Thermal
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

        add_to_expression_componentreserveup!(
            container,
            ThermalReserveUpExpression,
            ThermalReserveVariable,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
            time_steps,
        )
        add_to_expression_componentreservedown!(
            container,
            ThermalReserveDownExpression,
            ThermalReserveVariable,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
            time_steps,
        )

        # Add Served Expressions for Thermal
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

        add_to_expression_componentservedreserveup!(
            container,
            ThermalServedReserveUpExpression,
            ThermalReserveVariable,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
            time_steps,
        )
        add_to_expression_componentservedreservedown!(
            container,
            ThermalServedReserveDownExpression,
            ThermalReserveVariable,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
            time_steps,
        )
    end

    ###############################
    ####### Obj. Function #########
    ###############################

    # This function add the parameters for both variables DABidOut and DABidIn
    PSI.add_parameters!(
        container,
        DayAheadEnergyPrice(),
        hybrids,
        MerchantModelWithReserves(),
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
        MerchantModelWithReserves(),
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

    # This function add the parameters for each Ancillary Service Variable (Out and In)
    PSI.add_parameters!(
        container,
        AncillaryServicePrice(),
        hybrids,
        MerchantModelWithReserves(),
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
        dev_services = PSY.get_services(dev)
        for service in dev_services
            service_name = PSY.get_name(service)
            price_service_out = PSI.get_parameter_array(
                container,
                AncillaryServicePrice(),
                PSY.HybridSystem,
                "BidReserveVariableOut_$(service_name)",
            )
            sb_service_out = PSI.get_variable(
                container,
                BidReserveVariableOut(),
                typeof(service),
                service_name,
            )
            price_service_in = PSI.get_parameter_array(
                container,
                AncillaryServicePrice(),
                PSY.HybridSystem,
                "BidReserveVariableIn_$(service_name)",
            )
            sb_service_in = PSI.get_variable(
                container,
                BidReserveVariableIn(),
                typeof(service),
                service_name,
            )
            service_out_cost =
                -100.0 * Δt_DA * price_service_out[name, t] * sb_service_out[name, t]
            service_in_cost =
                -100.0 * Δt_DA * price_service_in[name, t] * sb_service_in[name, t]
            PSI.add_to_objective_variant_expression!(container, service_out_cost)
            PSI.add_to_objective_variant_expression!(container, service_in_cost)
        end
        if !isnothing(dev.thermal_unit)
            # Workaround
            t_gen = dev.thermal_unit
            three_cost = PSY.get_operation_cost(t_gen)
            C_th_fix = three_cost.fixed # $/h
            lin_cost_on_th = Δt_DA * C_th_fix * on_th[name, t]
            PSI.add_to_objective_invariant_expression!(container, lin_cost_on_th)
        end
    end

    # RT costs
    p_out = PSI.get_variable(container, PSI.ActivePowerOutVariable(), PSY.HybridSystem)
    p_in = PSI.get_variable(container, PSI.ActivePowerInVariable(), PSY.HybridSystem)

    # Thermal Variable Cost
    if !isempty(_hybrids_with_thermal)
        p_th = PSI.get_variable(container, ThermalPower(), PSY.HybridSystem)
    end
    # TODO: Decide if we include cost of curtailment or not
    # PSI.add_variable_cost!(container, RenewablePower(), _hybrids_with_renewable, MerchantModelWithReserves())
    # Battery Cost
    PSI.add_proportional_cost!(
        container,
        BatteryCharge(),
        _hybrids_with_storage,
        MerchantModelWithReserves(),
    )
    PSI.add_proportional_cost!(
        container,
        BatteryDischarge(),
        _hybrids_with_storage,
        MerchantModelWithReserves(),
    )

    # Storage Variable Cost
    if !isempty(_hybrids_with_storage)
        p_ch = PSI.get_variable(container, BatteryCharge(), PSY.HybridSystem)
        p_ds = PSI.get_variable(container, BatteryDischarge(), PSY.HybridSystem)
        if PSI.get_attribute(device_model, "regularization")
            PSI.add_proportional_cost!(
                container,
                ChargeRegularizationVariable(),
                _hybrids_with_storage,
                MerchantModelWithReserves(),
            )
            PSI.add_proportional_cost!(
                container,
                DischargeRegularizationVariable(),
                _hybrids_with_storage,
                MerchantModelWithReserves(),
            )
        end
    end

    if len_DA == 24
        res_slack_up = PSI.get_variable(container, SlackReserveUp(), PSY.HybridSystem)
        res_slack_dn = PSI.get_variable(container, SlackReserveDown(), PSY.HybridSystem)
    end

    # RT bids and DART arbitrage
    for t in T_rt, dev in hybrids
        name = PSY.get_name(dev)
        lin_cost_rt_out = -100.0 * Δt_RT * λ_rt_pos[name, t] * p_out[name, t]
        lin_cost_rt_in = 100.0 * Δt_RT * λ_rt_neg[name, t] * p_in[name, t]
        lin_cost_dart_out = 100.0 * Δt_RT * λ_dart_neg[name, t] * eb_da_out[name, tmap[t]]
        lin_cost_dart_in = -100.0 * Δt_RT * λ_dart_pos[name, t] * eb_da_in[name, tmap[t]]
        PSI.add_to_objective_variant_expression!(container, lin_cost_rt_out)
        PSI.add_to_objective_variant_expression!(container, lin_cost_rt_in)
        PSI.add_to_objective_variant_expression!(container, lin_cost_dart_out)
        PSI.add_to_objective_variant_expression!(container, lin_cost_dart_in)
        if !isnothing(dev.thermal_unit)
            # Workaround to add ThermalCost with a Linear Cost Since the model doesn't include PWL cost
            t_gen = dev.thermal_unit
            three_cost = PSY.get_operation_cost(t_gen)
            first_part = three_cost.variable[1]
            second_part = three_cost.variable[2]
            slope = (second_part[1] - first_part[1]) / (second_part[2] - first_part[2]) # $/MWh
            fix_cost = three_cost.fixed # $/h
            C_th_var = slope * 100.0 # Multiply by 100 to transform to $/pu
            lin_cost_p_th = Δt_RT * C_th_var * p_th[name, t]
            PSI.add_to_objective_invariant_expression!(container, lin_cost_p_th)
        end
        if !isnothing(dev.storage)
            VOM = dev.storage.operation_cost.variable.cost
            lin_cost_p_ch = 100.0 * Δt_RT * VOM * p_ch[name, t]
            lin_cost_p_ds = 100.0 * Δt_RT * VOM * p_ds[name, t]
            PSI.add_to_objective_invariant_expression!(container, lin_cost_p_ch)
            PSI.add_to_objective_invariant_expression!(container, lin_cost_p_ds)
        end
        if len_DA == 24
            dev_services = PSY.get_services(dev)
            for service in dev_services
                service_name = PSY.get_name(service)
                PSI.add_to_objective_invariant_expression!(
                    container,
                    1000.0 * res_slack_up[name, service_name, t],
                )
                PSI.add_to_objective_invariant_expression!(
                    container,
                    1000.0 * res_slack_dn[name, service_name, t],
                )
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

    # PCC Limits for Day-Ahead Bid Out
    add_constraints_dayaheadlimit_out_withreserves!(
        container,
        DayAheadBidOutRangeLimit,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # PCC Limits for Day-Ahead Bid In
    add_constraints_dayaheadlimit_in_withreserves!(
        container,
        DayAheadBidInRangeLimit,
        hybrids,
        MerchantModelWithReserves(),
        T_da,
    )

    # PCC Limits for Real-Time Bid Out
    add_constraints_realtimelimit_out_withreserves!(
        container,
        RealTimeBidOutRangeLimit,
        hybrids,
        MerchantModelWithReserves(),
        time_steps,
    )

    add_constraints_realtimelimit_in_withreserves!(
        container,
        RealTimeBidInRangeLimit,
        hybrids,
        MerchantModelWithReserves(),
        time_steps,
    )

    # Thermal
    if !isempty(_hybrids_with_thermal)
        # Thermal Limits with Reserves
        _add_thermallimit_withreserves!(
            container,
            ThermalReserveLimit,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
        )

        # Thermal Limit On without Reserves
        _add_constraints_thermalon_variableon!(
            container,
            ThermalOnVariableUb,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
        )

        # Thermal Limit Off without Reserves
        _add_constraints_thermalon_variableoff!(
            container,
            ThermalOnVariableLb,
            _hybrids_with_thermal,
            MerchantModelWithReserves(),
        )
    end
    # Battery Charging
    if !isempty(_hybrids_with_storage)
        # Discharging Limits with Reserves
        _add_constraints_discharging_reservelimit!(
            container,
            DischargingReservePowerLimit,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
        )

        # Discharging Limits without Reserves
        _add_constraints_batterydischargeon!(
            container,
            BatteryStatusDischargeOn,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
        )

        # Charging Limits with Reserves
        _add_constraints_charging_reservelimit!(
            container,
            ChargingReservePowerLimit,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
        )

        # Charging Limits without Reserve
        _add_constraints_batterychargeon!(
            container,
            BatteryStatusChargeOn,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
        )

        # Battery Balance
        _add_constraints_batterybalance!(
            container,
            BatteryBalance,
            _hybrids_with_storage,
            MerchantModelWithReserves(),
        )

        if PSI.get_attribute(device_model, "cycling")
            PSI.add_constraints!(
                container,
                CyclingCharge,
                _hybrids_with_storage,
                device_model,
                network_model,
            )
            PSI.add_constraints!(
                container,
                CyclingDischarge,
                _hybrids_with_storage,
                device_model,
                network_model,
            )
        end

        # Reserve Coverage
        for service in services
            _add_constraints_reservecoverage_withreserves!(
                container,
                ReserveCoverageConstraint,
                _hybrids_with_storage,
                service,
                MerchantModelWithReserves(),
            )
            _add_constraints_reservecoverage_withreserves_endofperiod!(
                container,
                ReserveCoverageConstraintEndOfPeriod,
                _hybrids_with_storage,
                service,
                MerchantModelWithReserves(),
            )
        end
    end

    if !isempty(_hybrids_with_renewable)
        # Add Renewable Limit without Reserves
        _add_constraints_renewablelimit!(
            container,
            RenewableActivePowerLimitConstraint,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
        )
        # Add Renewable Limit with Reserves
        _add_constraints_renewablereserve_limit!(
            container,
            RenewableReserveLimit,
            _hybrids_with_renewable,
            MerchantModelWithReserves(),
        )
    end

    # Asset Balance
    _add_constraints_energyassetbalance!(
        container,
        EnergyAssetBalance,
        hybrids,
        MerchantModelWithReserves(),
    )

    # Energy Bid Balance
    _add_constraints_energybidassetbalance!(
        container,
        EnergyBidAssetBalance,
        hybrids,
        MerchantModelWithReserves(),
    )

    # Reserve Bid Balance
    if !isempty(services)
        # Kinda Hacky. Undo this before merge
        _add_constraints_reserve_assignment!(
            container,
            HybridReserveAssignmentConstraint,
            hybrids,
            BidReserveVariableIn(),
            BidReserveVariableOut(),
            TotalReserve(),
        )
        _add_constraints_reservebalance!(
            container,
            ReserveBalance,
            hybrids,
            MerchantModelWithReserves(),
            time_steps,
        )
    end

    # Status PCC Operation Out ON
    _add_constraints_statusout!(
        container,
        StatusOutOn,
        hybrids,
        MerchantModelWithReserves(),
    )

    # Status PCC Operation Out In
    _add_constraints_statusin!(container, StatusInOn, hybrids, MerchantModelWithReserves())

    # Market Convergence to Assets

    _add_constraints_out_marketconvergence!(
        container,
        MarketOutConvergence,
        hybrids,
        MerchantModelWithReserves(),
    )

    _add_constraints_in_marketconvergence!(
        container,
        MarketInConvergence,
        hybrids,
        MerchantModelWithReserves(),
    )

    PSI.add_feedforward_arguments!(container, device_model, hybrids)
    PSI.add_feedforward_constraints!(container, device_model, hybrids)
    PSI.update_objective_function!(container)
    PSI.serialize_metadata!(container, PSI.get_output_dir(decision_model))
    return
end
