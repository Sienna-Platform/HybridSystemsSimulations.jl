###############################
###### Model Templates ########
###############################

# Some models are commented for RTS model

function set_uc_models!(template_uc)
    #set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    #set_device_model!(template_uc, Transformer2W, StaticBranchUnbounded)
    set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
    # Hydros are not needed for hybrid-focused tests under PSY5/PSI0.33
    # set_device_model!(template_uc, HydroDispatch, FixedOutput)
    set_device_model!(
        template_uc,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => false),
        ),
    )
    set_device_model!(
        template_uc,
        DeviceModel(
            PSY.EnergyReservoirStorage,
            StorageDispatchWithReserves;
            attributes = Dict{String, Any}(
                "reservation" => true,
                "cycling_limits" => false,
                "energy_target" => false,
                "complete_coverage" => false,
                "regularization" => true,
            ),
        ),
    )
    set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(
        template_uc,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
    )
    return
end

function update_ed_models!(template_ed)
    #set_device_model!(template_ed, ThermalMultiStart, ThermalStandardDispatch)
    set_device_model!(template_ed, ThermalStandard, ThermalBasicDispatch)
    # Hydros are not needed for hybrid-focused tests under PSY5/PSI0.33
    # set_device_model!(template_ed, HydroDispatch, FixedOutput)
    #set_device_model!(template_ed, HydroEnergyReservoir, HydroDispatchRunOfRiver)
    empty!(template_ed.services)
    return
end

function get_template_basic_uc_simulation()
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, InterruptiblePowerLoad, StaticPowerLoad)
    return template
end

function get_template_standard_uc_simulation()
    template = get_template_basic_uc_simulation()
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    return template
end

function get_thermal_dispatch_template_network(network = CopperPlatePowerModel)
    template = ProblemTemplate(network)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, MonitoredLine, StaticBranchBounds)
    set_device_model!(template, Line, StaticBranch)
    set_device_model!(template, Transformer2W, StaticBranch)
    set_device_model!(template, TapTransformer, StaticBranch)
    set_device_model!(template, TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless)
    return template
end

###############################
###### Line Templates #########
###############################

function set_ptdf_line_unbounded_template!(template_uc)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))
    return
end

function set_ptdf_line_template!(template_uc)
    set_device_model!(
        template_uc,
        DeviceModel(Line, StaticBranch; duals = [NetworkFlowConstraint]),
    )
    return
end

function set_dcp_line_unbounded_template!(template_uc)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranchUnbounded))
    return
end

function set_dcp_line_template!(template_uc)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    return
end

###############################
###### Get Templates ##########
###############################

### PTDF Bounded ####

function get_uc_ptdf_template(sys_rts_da)
    template_uc = ProblemTemplate(
        NetworkModel(
            PTDFPowerModel;
            use_slacks = true,
            PTDF_matrix = PTDF(sys_rts_da),
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_uc_models!(template_uc)
    set_ptdf_line_template!(template_uc)
    return template_uc
end

function get_ed_ptdf_template(sys_rts_da)
    template_ed = get_uc_ptdf_template(sys_rts_da)
    update_ed_models!(template_ed)
    return template_ed
end

#### PTDF Unbounded ####

function get_uc_ptdf_unbounded_template(sys_rts_da)
    template_uc = get_uc_ptdf_template(sys_rts_da)
    set_ptdf_line_unbounded_template!(template_uc)
    return template_uc
end

function get_ed_ptdf_unbounded_template(sys_rts_rt)
    template_ed = get_ed_ptdf_template(sys_rts_rt)
    set_ptdf_line_unbounded_template!(template_ed)
    return template_ed
end

#### CopperPlate ####

function get_uc_copperplate_template(sys_rts_da)
    template_uc = ProblemTemplate(
        NetworkModel(
            CopperPlatePowerModel;
            use_slacks = true,
            PTDF_matrix = PTDF(sys_rts_da),
            duals = [CopperPlateBalanceConstraint],
        ),
    )
    set_uc_models!(template_uc)
    set_ptdf_line_unbounded_template!(template_uc)
    return template_uc
end

function get_ed_copperplate_template(sys_rts_da)
    template_ed = get_uc_copperplate_template(sys_rts_da)
    update_ed_models!(template_ed)
    return template_ed
end

#### DCP  ####

function get_uc_dcp_template()
    template_uc = ProblemTemplate(
        NetworkModel(
            DCPPowerModel;
            use_slacks = true,
            duals = [NodalBalanceActiveConstraint],
        ),
    )
    set_uc_models!(template_uc)
    set_dcp_line_template!(template_uc)
    return template_uc
end

function get_ed_dcp_template()
    template_ed = get_uc_dcp_template()
    update_ed_models!(template_ed)
    return template_ed
end

# No emulation
function build_simulation_case(
    template_uc,
    template_ed,
    sys_da::System,
    sys_rt::System,
    num_steps::Int,
    mipgap::Float64,
    start_time,
)
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_da;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = true,
                optimizer_solve_log_print = true,
                direct_mode_optimizer = true,
                rebuild_model = false,
                store_variable_names = true,
                #check_numerical_bounds=false,
            ),
            DecisionModel(
                template_ed,
                sys_rt;
                name = "ED",
                optimizer = optimizer_with_attributes(Xpress.Optimizer),
                initialize_model = true,
                optimizer_solve_log_print = false,
                check_numerical_bounds = false,
                rebuild_model = false,
                calculate_conflict = true,
                store_variable_names = true,
                #export_pwl_vars = true,
            ),
        ],
    )

    # Set-up the sequence UC-ED
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "compact_sim",
        steps = num_steps,
        models = models,
        sequence = sequence,
        initial_time = start_time,
        simulation_folder = mktempdir(; cleanup = true),
    )

    return sim
end

# No emulation
function build_simulation_case_optimizer(
    template_uc,
    decision_optimizer,
    sys_da::System,
    sys_rt::System,
    num_steps::Int,
    mipgap::Float64,
    start_time,
)
    models = SimulationModels(;
        decision_models = [
            decision_optimizer,
            DecisionModel(
                template_uc,
                sys_da;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = true,
                optimizer_solve_log_print = false,
                direct_mode_optimizer = true,
                rebuild_model = false,
                store_variable_names = true,
                #check_numerical_bounds=false,
            ),
        ],
    )

    # Set-up the sequence Optimizer-UC
    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "UC" => [
                FixValueFeedforward(;
                    component_type = PSY.HybridSystem,
                    source = EnergyDABidOut,
                    affected_values = [ActivePowerOutVariable],
                ),
                FixValueFeedforward(;
                    component_type = PSY.HybridSystem,
                    source = EnergyDABidIn,
                    affected_values = [ActivePowerInVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "compact_sim",
        steps = num_steps,
        models = models,
        sequence = sequence,
        initial_time = start_time,
        simulation_folder = mktempdir(; cleanup = true),
    )

    return sim
end
