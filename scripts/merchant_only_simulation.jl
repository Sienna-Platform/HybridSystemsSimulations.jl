using Pkg
Pkg.activate("test")
Pkg.instantiate()

# Load SIIP Packages
using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
using PowerNetworkMatrices
using HybridSystemsSimulations
import OrderedCollections: OrderedDict
using JuMP
using DataFrames
using Dates
using CSV
using HiGHS

const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder
const HSS = HybridSystemsSimulations

###############################################################################
# Merchant-Only Simulation                                                    #
#                                                                             #
# This script runs a Simulation that contains ONLY the merchant decision      #
# model (`MerchantHybridEnergyCase`). The merchant model is driven by         #
# forecast day-ahead and real-time prices loaded from CSV files into the      #
# system `ext` dictionary, so no separate UC/ED model is needed.              #
###############################################################################

###############################
######## Load Scripts #########
###############################
include("modify_systems.jl")

# Use HiGHS so the script is runnable without a commercial solver.
solver = JuMP.optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 300.0,
    "log_to_console" => false,
    "mip_abs_gap" => 1e-1,
    "mip_rel_gap" => 1e-1,
)

###############################
######## Build System #########
###############################

horizon_merchant_rt = 24 * 12         # 288 5-min intervals = 24 hours
horizon_merchant_da = 24              # 24 hourly intervals = 24 hours
interval = Hour(24)

sys_rts_merchant = build_system(
    PSISystems,
    "modified_RTS_GMLC_RT_sys_noForecast",
)

# Add a hybrid system at the Chuhsi bus and adjust renewable curtailment.
modify_ren_curtailment_cost!(sys_rts_merchant)
add_hybrid_to_chuhsi_bus!(sys_rts_merchant)

transform_single_time_series!(sys_rts_merchant, horizon_merchant_rt, interval)

###############################
######## Forecast Prices ######
###############################

sys = sys_rts_merchant
sys.internal.ext = Dict{String, DataFrame}()
dic = PSY.get_ext(sys)

# CSVs with forecast DA and RT prices for the Chuhsi bus.
inputs_dir = joinpath(@__DIR__, "simulation_pipeline", "inputs")
bus_name = "chuhsi"
dic["λ_da_df"] = CSV.read(joinpath(inputs_dir, "$(bus_name)_DA_prices.csv"), DataFrame)
dic["λ_rt_df"] = CSV.read(joinpath(inputs_dir, "$(bus_name)_RT_prices.csv"), DataFrame)
dic["horizon_RT"] = horizon_merchant_rt
dic["horizon_DA"] = horizon_merchant_da

hy_sys = first(get_components(HybridSystem, sys))
PSY.set_ext!(hy_sys, deepcopy(dic))

###############################
######## Decision Model #######
###############################

decision_optimizer_DA = DecisionModel(
    MerchantHybridEnergyCase,
    ProblemTemplate(CopperPlatePowerModel),
    sys;
    optimizer=solver,
    calculate_conflict=true,
    store_variable_names=true,
    name="MerchantHybridEnergyCase_DA",
)
# Use the renewable time series that ships with the RT system.
decision_optimizer_DA.ext["RT"] = true

###############################
######## Simulation ###########
###############################

models = SimulationModels(decision_models=[decision_optimizer_DA])

sequence = SimulationSequence(
    models=models,
    ini_cond_chronology=InterProblemChronology(),
)

num_steps = 3
start_time = DateTime("2020-10-03T00:00:00")

sim = Simulation(
    name="merchant_only_sim",
    steps=num_steps,
    models=models,
    sequence=sequence,
    initial_time=start_time,
    simulation_folder=mktempdir(cleanup=true),
)

build!(sim)
execute!(sim; enable_progress_bar=true)

results = SimulationResults(sim)
result_opt = get_decision_problem_results(results, "MerchantHybridEnergyCase_DA")

da_bid_out = read_variable(result_opt, "EnergyDABidOut__HybridSystem")
da_bid_in = read_variable(result_opt, "EnergyDABidIn__HybridSystem")
rt_bid_out = read_variable(result_opt, "EnergyRTBidOut__HybridSystem")
rt_bid_in = read_variable(result_opt, "EnergyRTBidIn__HybridSystem")

@info "Merchant-only simulation finished" num_steps length(da_bid_out)
