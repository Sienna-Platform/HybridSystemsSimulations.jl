@testset "Hybrid DCPLossLess with HybridEnergyOnlyDispatch formulation" begin
    device_model = DeviceModel(
        PSY.HybridSystem,
        HybridEnergyOnlyDispatch;
        attributes = Dict{String, Any}("cycling" => false),
    )
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # Parameters Testing
    model =
        DecisionModel(MockOperationProblem, DCPPowerModel, sys; store_variable_names = true)
    mock_construct_device!(model, device_model)
    moi_tests(model, 1008, 0, 904, 376, 208, true)
    psi_checkobjfun_test(model, GAEVF)
end

@testset "Hybrid ACPPowerModel with HybridEnergyOnlyDispatch formulation" begin
    device_model = DeviceModel(
        PSY.HybridSystem,
        HybridEnergyOnlyDispatch;
        attributes = Dict{String, Any}("cycling" => false),
    )
    sys = PSB.build_system(PSITestSystems, "c_sys5_hybrid")

    # No Parameters Testing
    model = DecisionModel(MockOperationProblem, PTDFPowerModel, sys)
    mock_construct_device!(model, device_model)
    moi_tests(model, 1008, 0, 904, 376, 208, true)
    psi_checkobjfun_test(model, GAEVF)
end
