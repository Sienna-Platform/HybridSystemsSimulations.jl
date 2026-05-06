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

**Input data:**

  - **Hybrid-attached time series:** Each [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem)
    must have a bus-selected scalar day-ahead energy price series whose name is given by
    `hybrid_energy_price_time_series_name(<day_ahead_key>)` (default key `"DA"`), stored as
    `InfrastructureSystems.SingleTimeSeries` / deterministic forecast. Values are taken over the
    model horizon from forecast timestamps starting at the problem initial time.
"""
struct DayAheadEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    RealTimeEnergyPrice

Objective function parameter for real-time energy price.

Docs abbreviation: ``\\Pi^*_{\\text{RT},t}`` (USD/MWh). Used in the merchant profit
expression for RT energy and DART spread.

**Input data:**

  - **Hybrid-attached time series:** Real-time energy price uses
    `hybrid_energy_price_time_series_name(<real_time_key>)` (default key `"RT"`). Day-ahead ↔
    real-time alignment for spread terms uses variable axis sizes and an internal index map derived
    from model horizons, not hybrid `ext`.
"""
struct RealTimeEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    AncillaryServicePrice

Objective function parameter for ancillary service price.

Docs abbreviation: ``\\Pi^*_{p,t}`` (USD/MWh) for service ``p \\in P``. Used in the DA
profit term for ancillary services (``sb^{\\text{out}}`` + ``sb^{\\text{in}}``).

**Input data:**

  - **Hybrid-attached time series:** For each attached ancillary product, a scalar series named per
    `hybrid_ancillary_service_price_time_series_name(<service_name>, <day_ahead_key>)`. Used by
    [`MerchantHybridCooptimizerCase`](@ref) when services are attached to the hybrid.
"""
struct AncillaryServicePrice <: PSI.ObjectiveFunctionParameter end

struct EnergyTargetParameter <: PSI.VariableValueParameter end

"""
    CyclingChargeLimitParameter

Variable-value parameter that provides the right-hand side for the storage charging
cycle limit: ``\\eta_{\\text{ch}} \\Delta t \\sum_t p_{\\text{ch},t} - c_{\\text{ch}}^- \\leq C_{\\text{st}} E_{\\max,\\text{st}}``. Used with
[`CyclingChargeLimitFeedforward`](@ref) in recurrent simulations to pass cumulative
cycling from previous horizons.

**Input data:**

  - **Storage limits:** Initial values (when not updated from state) are computed from the
    hybrid's storage using `PowerSystems.get_cycle_limits` and
    `PowerSystems.get_storage_level_limits`.
  - **State updates:** In recurrent runs, values are updated from the simulation state
    (cumulative charge usage).
"""
struct CyclingChargeLimitParameter <: PSI.VariableValueParameter end

"""
    CyclingDischargeLimitParameter

Variable-value parameter for the storage discharging cycle limit:
``(\\Delta t/\\eta_{\\text{ds}}) \\sum_t p_{\\text{ds},t} - c_{\\text{ds}}^- \\leq C_{\\text{st}} E_{\\max,\\text{st}}``. Used with
[`CyclingDischargeLimitFeedforward`](@ref).

**Input data:**

  - Same as [`CyclingChargeLimitParameter`](@ref): initial values based on
    `PowerSystems.get_cycle_limits` and `PowerSystems.get_storage_level_limits` for the
    hybrid's storage; in recurrent runs, updated from state (cumulative discharge usage).
"""
struct CyclingDischargeLimitParameter <: PSI.VariableValueParameter end

PSI.should_write_resulting_value(::Type{DayAheadEnergyPrice}) = true
PSI.should_write_resulting_value(::Type{RealTimeEnergyPrice}) = true

# convert_result_to_natural_units(::Type{EnergyTargetParameter}) = true
