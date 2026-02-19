@testset "Test HybridSystem Simulation Only UC" begin
    sys_uc = PSB.build_system(PSITestSystems, "c_sys5_hybrid_uc")

    template_uc = get_template_standard_uc_simulation()
    set_device_model!(
        template_uc,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => false),
        ),
    )
    set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel; use_slacks = true))

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_uc;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
        ],
    )

    sequence =
        SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )

    sim = Simulation(;
        name = "hybrid_test",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    @test execute!(sim) == PSI.RunStatus.SUCCESSFUL
end
@testset "Test HybridSystem Simulation UC + ED" begin
    sys_uc = PSB.build_system(PSITestSystems, "c_sys5_hybrid_uc")
    sys_ed = PSB.build_system(PSITestSystems, "c_sys5_hybrid_ed")

    template_uc = get_template_standard_uc_simulation()
    set_device_model!(
        template_uc,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => false),
        ),
    )
    set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel; use_slacks = true))
    template_ed = get_thermal_dispatch_template_network(
        NetworkModel(CopperPlatePowerModel; use_slacks = true),
    )
    set_device_model!(
        template_ed,
        DeviceModel(
            PSY.HybridSystem,
            HybridEnergyOnlyDispatch;
            attributes = Dict{String, Any}("cycling" => false),
        ),
    )

    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_uc;
                name = "UC",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
            DecisionModel(
                template_ed,
                sys_ed;
                name = "ED",
                optimizer = HiGHS_optimizer,
                initialize_model = false,
            ),
        ],
    )

    sequence =
        SimulationSequence(;
            models = models,
            ini_cond_chronology = InterProblemChronology(),
        )

    sim = Simulation(;
        name = "hybrid_test",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(; cleanup = true),
    )
    build_out = build!(sim)
    @test build_out == PSI.BuildStatus.BUILT
    execute_out = execute!(sim)
    @test execute_out == PSI.RunStatus.SUCCESSFUL
end
