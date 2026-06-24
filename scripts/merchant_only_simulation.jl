using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"))
Pkg.instantiate()

# Load SIIP Packages
using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
using HybridSystemsSimulations
using JuMP
using DataFrames
using Dates
using CSV
using HiGHS
using TimeSeries

const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
const IS = InfrastructureSystems
const HSS = HybridSystemsSimulations

###############################################################################
# Merchant-Only Simulation                                                    #
#                                                                             #
# This script runs a Simulation that contains ONLY the merchant decision      #
# model (`MerchantHybridEnergyCase`). The merchant model is driven by         #
# day-ahead and real-time market prices attached to the hybrid as time        #
# series, so no separate UC/ED model is needed.                               #
###############################################################################

# Reuse the test utilities for building the hybrid and attaching market prices.
const TEST_DIR = joinpath(@__DIR__, "..", "test")
include(joinpath(TEST_DIR, "test_utils", "function_utils.jl"))

# Use HiGHS so the script is runnable without a commercial solver.
HiGHS_optimizer = JuMP.optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 300.0,
    "log_to_console" => false,
    "mip_abs_gap" => 1e-1,
    "mip_rel_gap" => 1e-1,
)

###############################
######## Build System #########
###############################

sys = PSB.build_RTS_GMLC_RT_sys(; raw_data = PSB.RTS_DIR, horizon = 24, interval = Hour(1))

# Add a hybrid system at the Chuhsi bus, adjust renewable curtailment, and
# attach the day-ahead and real-time market price time series.
modify_ren_curtailment_cost!(sys)
add_hybrid_to_chuhsi_bus!(sys; horizon_rt_steps = 288)
hy_sys = first(get_components(HybridSystem, sys))
attach_hybrid_market_time_series!(
    sys,
    hy_sys;
    bus_name = "chuhsi",
    rt_steps = 288,
    da_steps = 288,
    injection_rt_steps = max(288, 300),
    use_rt_resolution_for_da = true,
)
strip_non_hybrid_single_time_series!(sys)

###############################
######## Decision Model #######
###############################

template = ProblemTemplate(CopperPlatePowerModel)
set_device_model!(template, DeviceModel(PSY.HybridSystem, HybridEnergyOnlyDispatch))
decision_optimizer_DA = DecisionModel(
    MerchantHybridEnergyCase,
    template,
    sys;
    optimizer = HiGHS_optimizer,
    calculate_conflict = true,
    store_variable_names = true,
    initial_time = DateTime("2020-10-03T00:00:00"),
    horizon = Hour(24),
    resolution = Minute(5),
    interval = Hour(1),
    name = "MerchantHybridEnergyCase_DA",
)

###############################
######## Simulation ###########
###############################

models = SimulationModels(; decision_models = [decision_optimizer_DA])

sequence = SimulationSequence(;
    models = models,
    ini_cond_chronology = InterProblemChronology(),
)

num_steps = 1
start_time = DateTime("2020-10-03T00:00:00")

sim = Simulation(;
    name = "merchant_only_sim",
    steps = num_steps,
    models = models,
    sequence = sequence,
    initial_time = start_time,
    simulation_folder = mktempdir(; cleanup = true),
)

build!(sim)
execute!(sim; enable_progress_bar = true)

results = SimulationResults(sim)
result_opt = get_decision_problem_results(results, "MerchantHybridEnergyCase_DA")

da_bid_out = read_variable(result_opt, "EnergyDABidOut__HybridSystem")
da_bid_in = read_variable(result_opt, "EnergyDABidIn__HybridSystem")
rt_bid_out = read_variable(result_opt, "EnergyRTBidOut__HybridSystem")
rt_bid_in = read_variable(result_opt, "EnergyRTBidIn__HybridSystem")

@info "Merchant-only simulation finished" num_steps length(da_bid_out)
