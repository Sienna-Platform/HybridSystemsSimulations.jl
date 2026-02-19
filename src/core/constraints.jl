### Define Constraints using PSI.ConstraintType ###

###################
### Upper Level ###
###################

## DA Bid Limits ##
struct DayAheadBidOutRangeLimit <: PSI.ConstraintType end
struct DayAheadBidInRangeLimit <: PSI.ConstraintType end

## RT Bid Limits ##
struct RealTimeBidOutRangeLimit <: PSI.ConstraintType end
struct RealTimeBidInRangeLimit <: PSI.ConstraintType end

## Energy Market Asset Balance ##
struct EnergyBidAssetBalance <: PSI.ConstraintType end

## AS Market Convergence ##
struct MarketOutConvergence <: PSI.ConstraintType end
struct MarketInConvergence <: PSI.ConstraintType end

## Internal Asset Bidding with AS ##
# Thermal
struct ThermalBidUp <: PSI.ConstraintType end
struct ThermalBidDown <: PSI.ConstraintType end
# Renewable
struct RenewableBidUp <: PSI.ConstraintType end
struct RenewableBidDown <: PSI.ConstraintType end
# Battery
struct BatteryChargeBidUp <: PSI.ConstraintType end
struct BatteryChargeBidDown <: PSI.ConstraintType end
struct BatteryDischargeBidUp <: PSI.ConstraintType end
struct BatteryDischargeBidDown <: PSI.ConstraintType end

##  Across Markets Balance ##
struct BidBalanceOut <: PSI.ConstraintType end
struct BidBalanceIn <: PSI.ConstraintType end
struct StatusOutOn <: PSI.ConstraintType end
struct StatusInOn <: PSI.ConstraintType end

## AS for Components
struct ReserveCoverageConstraint <: PSI.ConstraintType end
struct ReserveCoverageConstraintEndOfPeriod <: PSI.ConstraintType end
struct ChargingReservePowerLimit <: PSI.ConstraintType end
struct DischargingReservePowerLimit <: PSI.ConstraintType end
struct ThermalReserveLimit <: PSI.ConstraintType end
struct RenewableReserveLimit <: PSI.ConstraintType end

## Auxiliary for Output
struct ReserveBalance <: PSI.ConstraintType end
# Used for DeviceModels inside UC/ED to equate with the ActivePowerReserveVariable
struct HybridReserveAssignmentConstraint <: PSI.ConstraintType end

###################
### Lower Level ###
###################

struct EnergyAssetBalance <: PSI.ConstraintType end
struct ThermalOnVariableUb <: PSI.ConstraintType end
struct ThermalOnVariableLb <: PSI.ConstraintType end
struct BatteryStatusChargeOn <: PSI.ConstraintType end
struct BatteryStatusDischargeOn <: PSI.ConstraintType end
struct BatteryBalance <: PSI.ConstraintType end
struct CyclingCharge <: PSI.ConstraintType end
struct CyclingDischarge <: PSI.ConstraintType end
struct ChargeRegularizationConstraint <: PSI.ConstraintType end
struct DischargeRegularizationConstraint <: PSI.ConstraintType end
struct StateofChargeTargetConstraint <: PSI.ConstraintType end
struct RenewableActivePowerLimitConstraint <: PSI.ConstraintType end

###################
### Feedforwards ###
###################

struct FeedForwardCyclingChargeConstraint <: PSI.ConstraintType end
struct FeedForwardCyclingDischargeConstraint <: PSI.ConstraintType end

##############################################
### Dual Optimality Conditions Constraints ###
##############################################
# Names track the variable types in variables.jl
"""
    OptConditionThermalPower

Constraint enforcing KKT stationarity for thermal power in the merchant (lower-level)
model: links dual of thermal limits (``\\mu^{\\text{ThUb}}``, ``\\mu^{\\text{ThLb}}``) to the thermal power variable.
Used in bilevel/MPEC formulations.
"""
struct OptConditionThermalPower <: PSI.ConstraintType end

"""
    OptConditionRenewablePower

Constraint enforcing KKT stationarity for renewable power (``p_{\\text{re},t}``) in the merchant
model; ties duals of renewable limit (``\\mu^{\\text{ReUb}}``, ``\\mu^{\\text{ReLb}}``) to the renewable power variable.
"""
struct OptConditionRenewablePower <: PSI.ConstraintType end

"""
    OptConditionBatteryCharge

Constraint enforcing KKT stationarity for storage charging (``p_{\\text{ch},t}``) in the merchant
model; involves duals ``\\mu^{\\text{ChUb}}``, ``\\mu^{\\text{ChLb}}`` and charge limits.
"""
struct OptConditionBatteryCharge <: PSI.ConstraintType end

"""
    OptConditionBatteryDischarge

Constraint enforcing KKT stationarity for storage discharging (``p_{\\text{ds},t}``) in the merchant
model; involves duals ``\\mu^{\\text{DsUb}}``, ``\\mu^{\\text{DsLb}}``.
"""
struct OptConditionBatteryDischarge <: PSI.ConstraintType end

"""
    OptConditionEnergyVariable

Constraint enforcing KKT stationarity for the energy variable at the PCC in the
merchant model. #TODO DOCS
"""
struct OptConditionEnergyVariable <: PSI.ConstraintType end

###############################################
##### Complementaty Slackness Constraints #####
###############################################
# Names track the constraint types and their Meta Ub and Lb
"""
    ComplementarySlacknessEnergyAssetBalanceUb

Complementary slackness constraint (upper bound) for the energy asset balance
equation in the merchant model; used in MPEC/bilevel reformulation.
"""
struct ComplementarySlacknessEnergyAssetBalanceUb <: PSI.ConstraintType end

"""
    ComplementarySlacknessEnergyAssetBalanceLb

Complementary slackness constraint (lower bound) for the energy asset balance.
"""
struct ComplementarySlacknessEnergyAssetBalanceLb <: PSI.ConstraintType end

struct ComplementarySlacknessThermalOnVariableUb <: PSI.ConstraintType end
struct ComplementarySlacknessThermalOnVariableLb <: PSI.ConstraintType end

"""
    ComplementarySlacknessRenewableActivePowerLimitConstraintUb

Complementary slackness (upper bound) for renewable active power limit (``p_{\\text{re},t} \\leq P^*_{\\text{re},t}``).
"""
struct ComplementarySlacknessRenewableActivePowerLimitConstraintUb <: PSI.ConstraintType end

"""
    ComplementarySlacknessRenewableActivePowerLimitConstraintLb

Complementary slackness (lower bound) for renewable active power limit.
"""
struct ComplementarySlacknessRenewableActivePowerLimitConstraintLb <: PSI.ConstraintType end

"""
    ComplementarySlacknessBatteryStatusDischargeOnUb

Complementary slackness (upper bound) for battery status discharge-on constraint (``ss_{\\text{st},t}``).
"""
struct ComplementarySlacknessBatteryStatusDischargeOnUb <: PSI.ConstraintType end
"""
    ComplementarySlacknessBatteryStatusDischargeOnLb

Complementary slackness (lower bound) for battery status discharge-on constraint.
"""
struct ComplementarySlacknessBatteryStatusDischargeOnLb <: PSI.ConstraintType end

"""
    ComplementarySlacknessBatteryStatusChargeOnUb

Complementary slackness (upper bound) for battery status charge-on constraint.
"""
struct ComplementarySlacknessBatteryStatusChargeOnUb <: PSI.ConstraintType end
"""
    ComplementarySlacknessBatteryStatusChargeOnLb

Complementary slackness (lower bound) for battery status charge-on constraint.
"""
struct ComplementarySlacknessBatteryStatusChargeOnLb <: PSI.ConstraintType end

"""
    ComplementarySlacknessBatteryBalanceUb

Complementary slackness (upper bound) for storage energy balance (``e_{\\text{st},t}``).
"""
struct ComplementarySlacknessBatteryBalanceUb <: PSI.ConstraintType end
"""
    ComplementarySlacknessBatteryBalanceLb

Complementary slackness (lower bound) for storage energy balance.
"""
struct ComplementarySlacknessBatteryBalanceLb <: PSI.ConstraintType end

"""
    ComplentarySlacknessCyclingCharge

Complementary slackness for the charging cycle limit (``c_{\\text{ch}}^-``); note spelling
"Complentary" is kept for API compatibility.
"""
struct ComplentarySlacknessCyclingCharge <: PSI.ConstraintType end

"""
    ComplentarySlacknessCyclingDischarge

Complementary slackness for the discharging cycle limit (``c_{\\text{ds}}^-``).
"""
struct ComplentarySlacknessCyclingDischarge <: PSI.ConstraintType end

"""
    ComplementarySlacknessEnergyLimitUb

Complementary slackness (upper bound) for storage energy capacity (``e_{\\text{st},t} \\leq E_{\\max,\\text{st}}``).
"""
struct ComplementarySlacknessEnergyLimitUb <: PSI.ConstraintType end
"""
    ComplementarySlacknessEnergyLimitLb

Complementary slackness (lower bound) for storage energy capacity.
"""
struct ComplementarySlacknessEnergyLimitLb <: PSI.ConstraintType end

"""
    StrongDualityCut

Constraint that enforces strong duality for the merchant (lower-level) problem
in a bilevel formulation: objective value equals dual objective (or equivalent
cut), so that the lower level is replaced by its KKT conditions.
"""
struct StrongDualityCut <: PSI.ConstraintType end
