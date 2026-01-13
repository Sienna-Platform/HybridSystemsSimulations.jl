module HybridSystemsSimulations

# Device Formulations
export HybridEnergyOnlyDispatch
export HybridFixedDA
export HybridDispatchWithReserves

# Decision Models
export MerchantHybridEnergyCase
export MerchantHybridEnergyFixedDA
export MerchantHybridCooptimizerCase
export MerchantHybridBilevelCase

# Variables
export EnergyDABidOut
export EnergyDABidIn
export EnergyRTBidOut
export EnergyRTBidIn
export BidReserveVariableOut
export BidReserveVariableIn
export ReserveVariableOut
export ReserveVariableIn
export TotalReserve

# Auxiliary variables

# FeedForward
export CyclingChargeLimitFeedforward
export CyclingDischargeLimitFeedforward

# Constraints
export OptConditionRenewablePower
export OptConditionBatteryCharge
export OptConditionBatteryDischarge
export OptConditionEnergyVariable
export OptConditionThermalPower
export ComplementarySlacknessRenewableActivePowerLimitConstraintUb
export ComplementarySlacknessEnergyAssetBalanceUb
export ComplementarySlacknessEnergyAssetBalanceLb
export ComplementarySlacknessBatteryStatusDischargeOnUb
export ComplementarySlacknessBatteryStatusDischargeOnLb
export ComplementarySlacknessBatteryStatusChargeOnUb
export ComplementarySlacknessBatteryStatusChargeOnLb
export ComplementarySlacknessBatteryBalanceUb
export ComplementarySlacknessBatteryBalanceLb
export ComplentarySlacknessCyclingCharge
export ComplentarySlacknessCyclingDischarge
export ComplementarySlacknessEnergyLimitUb
export ComplementarySlacknessEnergyLimitLb
#export ComplementarySlacknessThermalOnVariableOn
#export ComplementarySlacknessThermalOnVariableOff
export StrongDualityCut

# Parameters
export DayAheadEnergyPrice
export RealTimeEnergyPrice
export AncillaryServicePrice
export CyclingDischargeLimitParameter
export CyclingChargeLimitParameter

import MathOptInterface as MOI
import PowerSimulations as PSI
import PowerSystems as PSY
import PowerSimulations.PM as PM
import PowerSimulations.IS as IS
import PowerSimulations.IS.Optimization as ISOPT
import JuMP
import Dates
import DataFrames
import DataStructures: OrderedDict

using DocStringExtensions
@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

include("core/decision_models.jl")
include("core/formulations.jl")
include("core/parameters.jl")
include("core/aux_variables.jl")
include("core/variables.jl")
include("core/constraints.jl")
include("core/expressions.jl")
include("add_to_expression.jl")
include("hybrid_system_decision_models.jl")
include("hybrid_system_device_models.jl")
include("add_variables.jl")
include("add_aux_variables.jl")
include("add_parameters.jl")
include("add_constraints.jl")
include("objective_function.jl")
include("feedforwards.jl")
include("decision_models/only_energy_decision_model.jl")
include("decision_models/cooptimizer_decision_model.jl")
include("decision_models/bilevel_decision_model.jl")
include("hybrid_system_constructor.jl")

end
