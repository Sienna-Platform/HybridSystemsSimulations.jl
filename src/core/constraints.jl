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
"""Links day-ahead energy bids to internal asset power (upper level)."""
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
"""Binary status for hybrid output (generation) direction at the PCC."""
struct StatusOutOn <: PSI.ConstraintType end
"""Binary status for hybrid input (consumption) direction at the PCC."""
struct StatusInOn <: PSI.ConstraintType end

## AS for Components
"""Ensures storage has sufficient energy to meet ancillary service commitments."""
struct ReserveCoverageConstraint <: PSI.ConstraintType end
"""End-of-period energy coverage for ancillary services."""
struct ReserveCoverageConstraintEndOfPeriod <: PSI.ConstraintType end
"""Upper bound on charging power allocated to ancillary services."""
struct ChargingReservePowerLimit <: PSI.ConstraintType end
"""Upper bound on discharging power allocated to ancillary services."""
struct DischargingReservePowerLimit <: PSI.ConstraintType end
"""Upper bound on thermal power allocated to ancillary services."""
struct ThermalReserveLimit <: PSI.ConstraintType end
"""Upper bound on renewable power allocated to ancillary services."""
struct RenewableReserveLimit <: PSI.ConstraintType end

## Auxiliary for Output
"""Total reserve at PCC equals sum of component reserve allocations."""
struct ReserveBalance <: PSI.ConstraintType end
"""Links component reserve variables to total reserve at the PCC."""
struct HybridReserveAssignmentConstraint <: PSI.ConstraintType end

###################
### Lower Level ###
###################

"""Net internal power (thermal + renewable + discharge − charge − load) equals net PCC power (out − in)."""
struct EnergyAssetBalance <: PSI.ConstraintType end
"""Thermal power upper bound: ``p^{\\text{th}}_t \\leq u^{\\text{th}}_t P_{\\max,\\text{th}}``."""
struct ThermalOnVariableUb <: PSI.ConstraintType end
"""Thermal power lower bound: ``p^{\\text{th}}_t \\geq u^{\\text{th}}_t P_{\\min,\\text{th}}``."""
struct ThermalOnVariableLb <: PSI.ConstraintType end
"""Charge power upper bound when not discharging: ``p^{\\text{ch}}_t \\leq (1 - ss^{\\text{st}}_t) P_{\\max,\\text{ch}}``."""
struct BatteryStatusChargeOn <: PSI.ConstraintType end
"""Discharge power upper bound when discharging: ``p^{\\text{ds}}_t \\leq ss^{\\text{st}}_t P_{\\max,\\text{ds}}``."""
struct BatteryStatusDischargeOn <: PSI.ConstraintType end
"""Storage energy balance: ``e^{\\text{st}}_t = e^{\\text{st}}_{t-1} + \\Delta t(\\eta_{\\text{ch}} p^{\\text{ch}}_t - p^{\\text{ds}}_t/\\eta_{\\text{ds}})``."""
struct BatteryBalance <: PSI.ConstraintType end
"""Cumulative charging energy over horizon ≤ ``C_{\\text{st}} E_{\\max,\\text{st}}``."""
struct CyclingCharge <: PSI.ConstraintType end
"""Cumulative discharging energy over horizon ≤ ``C_{\\text{st}} E_{\\max,\\text{st}}``."""
struct CyclingDischarge <: PSI.ConstraintType end
"""Regularization on charge power changes (when `"regularization" => true`): penalizes ``|\\Delta p^{\\text{ch}}_t|``-style changes. See formulation docstrings for full constraint."""
struct ChargeRegularizationConstraint <: PSI.ConstraintType end
"""Regularization on discharge power changes (when `"regularization" => true`): penalizes ``|\\Delta p^{\\text{ds}}_t|``-style changes. See formulation docstrings for full constraint."""
struct DischargeRegularizationConstraint <: PSI.ConstraintType end
"""End-of-horizon storage energy target (when `"energy_target" => true`): ``e^{\\text{st}}_T = E^{\\text{st}}_T``."""
struct StateofChargeTargetConstraint <: PSI.ConstraintType end
"""Renewable power upper bound: ``p^{\\text{re}}_t \\leq P^{*,\\text{re}}_t``."""
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

Constraint enforcing Karush-Kuhn-Tucker (KKT) stationarity for thermal power in the merchant (lower-level)
model: links dual of thermal limits (``\\mu^{\\text{ThUb}}``, ``\\mu^{\\text{ThLb}}``) to the thermal power variable.
Used in bilevel/mathematical program with equilibrium constraints (MPEC) formulations.
"""
struct OptConditionThermalPower <: PSI.ConstraintType end

"""
    OptConditionRenewablePower

Constraint enforcing Karush-Kuhn-Tucker (KKT) stationarity for renewable power (``p_{\\text{re},t}``) in the merchant
model; ties duals of renewable limit (``\\mu^{\\text{ReUb}}``, ``\\mu^{\\text{ReLb}}``) to the renewable power variable.
"""
struct OptConditionRenewablePower <: PSI.ConstraintType end

"""
    OptConditionBatteryCharge

Constraint enforcing Karush-Kuhn-Tucker (KKT) stationarity for storage charging (``p_{\\text{ch},t}``) in the merchant
model; involves duals ``\\mu^{\\text{ChUb}}``, ``\\mu^{\\text{ChLb}}`` and charge limits.
"""
struct OptConditionBatteryCharge <: PSI.ConstraintType end

"""
    OptConditionBatteryDischarge

Constraint enforcing Karush-Kuhn-Tucker (KKT) stationarity for storage discharging (``p_{\\text{ds},t}``) in the merchant
model; involves duals ``\\mu^{\\text{DsUb}}``, ``\\mu^{\\text{DsLb}}``.
"""
struct OptConditionBatteryDischarge <: PSI.ConstraintType end

"""
    OptConditionEnergyVariable

Constraint enforcing Karush-Kuhn-Tucker (KKT) stationarity for the energy variable at the point of common coupling (PCC) in the
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
equation in the merchant model; used in mathematical program with equilibrium constraints (MPEC)/bilevel reformulation.
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
cut), so that the lower level is replaced by its Karush-Kuhn-Tucker (KKT) conditions.
"""
struct StrongDualityCut <: PSI.ConstraintType end
