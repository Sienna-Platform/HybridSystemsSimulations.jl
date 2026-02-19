const CYCLES_PER_DAY = 1.37
const HOURS_IN_DAY = 24
const REG_COST = 0.001

struct RenewablePowerTimeSeries <: PSI.TimeSeriesParameter end
struct ElectricLoadTimeSeries <: PSI.TimeSeriesParameter end

"""
    DayAheadEnergyPrice

Objective function parameter for day-ahead energy price.

Docs abbreviation: ``\\Pi^*_{\\text{DA},t}`` (USD/MWh). Used in the merchant objective
(e.g. ``f_{\\text{DA},t}`` term) when building the decision model.
"""
struct DayAheadEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    RealTimeEnergyPrice

Objective function parameter for real-time energy price.

Docs abbreviation: ``\\Pi^*_{\\text{RT},t}`` (USD/MWh). Used in the merchant profit
expression for RT energy and DART spread.
"""
struct RealTimeEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    AncillaryServicePrice

Objective function parameter for ancillary service price.

Docs abbreviation: ``\\Pi^*_{p,t}`` (USD/MWh) for service ``p \\in P``. Used in the DA
profit term for AS (``sb^{\\text{out}}`` + ``sb^{\\text{in}}``).
"""
struct AncillaryServicePrice <: PSI.ObjectiveFunctionParameter end

struct EnergyTargetParameter <: PSI.VariableValueParameter end

"""
    CyclingChargeLimitParameter

Variable-value parameter that provides the right-hand side for the storage charging
cycle limit: ``\\eta_{\\text{ch}} \\Delta t \\sum_t p_{\\text{ch},t} - c_{\\text{ch}}^- \\leq C_{\\text{st}} E_{\\max,\\text{st}}``. Used with
[`CyclingChargeLimitFeedforward`](@ref) in recurrent simulations to pass cumulative
cycling from previous horizons.
"""
struct CyclingChargeLimitParameter <: PSI.VariableValueParameter end

"""
    CyclingDischargeLimitParameter

Variable-value parameter for the storage discharging cycle limit:
``(\\Delta t/\\eta_{\\text{ds}}) \\sum_t p_{\\text{ds},t} - c_{\\text{ds}}^- \\leq C_{\\text{st}} E_{\\max,\\text{st}}``. Used with
[`CyclingDischargeLimitFeedforward`](@ref).
"""
struct CyclingDischargeLimitParameter <: PSI.VariableValueParameter end

PSI.should_write_resulting_value(::Type{DayAheadEnergyPrice}) = true
PSI.should_write_resulting_value(::Type{RealTimeEnergyPrice}) = true

# convert_result_to_natural_units(::Type{EnergyTargetParameter}) = true
