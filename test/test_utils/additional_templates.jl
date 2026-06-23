###############################
###### Model Templates ########
###############################

function set_uc_models!(template_uc)
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, TapTransformer, StaticBranchUnbounded)
    set_device_model!(
        template_uc,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => false),
        ),
    )
    set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
    set_service_model!(
        template_uc,
        ServiceModel(VariableReserve{ReserveDown}, RangeReserve),
    )
    return
end

function get_hss_template_basic_uc_simulation()
    template = ProblemTemplate(CopperPlatePowerModel)
    set_device_model!(template, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template, PowerLoad, StaticPowerLoad)
    set_device_model!(template, InterruptiblePowerLoad, StaticPowerLoad)
    return template
end

function get_hss_template_standard_uc_simulation()
    template = get_hss_template_basic_uc_simulation()
    set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
    return template
end

function get_hss_thermal_dispatch_template_network(network = CopperPlatePowerModel)
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

function set_dcp_line_template!(template_uc)
    set_device_model!(template_uc, DeviceModel(Line, StaticBranch))
    return
end

###############################
###### Get Templates ##########
###############################

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

function build_simulation_case_optimizer(
    template_uc,
    decision_optimizer,
    sys_da::System,
    _sys_rt::System,
    num_steps::Int,
    _mipgap::Float64,
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
                # PSI 0.34: later stage horizon must not exceed prior.
                horizon = Hour(24),
                interval = Hour(1),
                initialize_model = true,
                optimizer_solve_log_print = false,
                direct_mode_optimizer = true,
                rebuild_model = false,
                store_variable_names = true,
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
