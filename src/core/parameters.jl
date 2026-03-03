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

  - **System ext:** The [`ext` supplemental data dictionary](@extref additional_fields) on
    [`PowerSystems.System`](@extref PowerSystems.System) must contain `\"λ_da_df\"`, a
    `DataFrame` with column `"DateTime"` and one column per bus name, and optionally
    `\"horizon_DA\"::Int` giving the number of day-ahead steps.
  - **Hybrid ext:** Each [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem)
    reads the same keys from its own [`ext` dictionary](@extref additional_fields); values are
    sliced starting at the current forecast time and used over the model horizon.
"""
struct DayAheadEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    RealTimeEnergyPrice

Objective function parameter for real-time energy price.

Docs abbreviation: ``\\Pi^*_{\\text{RT},t}`` (USD/MWh). Used in the merchant profit
expression for RT energy and DART spread.

**Input data:**

  - **System ext:** The [`ext` supplemental data dictionary](@extref additional_fields) on
    [`PowerSystems.System`](@extref PowerSystems.System) must contain `\"λ_rt_df\"`, a
    `DataFrame` with column `"DateTime"` and one column per bus name, and optionally
    `\"horizon_RT\"::Int` giving the number of real-time steps.
  - **Hybrid ext:** Each [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem)
    reads `\"λ_rt_df\"`, `\"horizon_RT\"`, and a mapping `\"tmap\"` from its own
    [`ext` dictionary](@extref additional_fields), used to align real-time steps to day-ahead
    steps where needed.
"""
struct RealTimeEnergyPrice <: PSI.ObjectiveFunctionParameter end

"""
    AncillaryServicePrice

Objective function parameter for ancillary service price.

Docs abbreviation: ``\\Pi^*_{p,t}`` (USD/MWh) for service ``p \\in P``. Used in the DA
profit term for ancillary services (``sb^{\\text{out}}`` + ``sb^{\\text{in}}``).

**Input data:**

  - **Hybrid ext:** For each service, the hybrid's [`ext` dictionary](@extref additional_fields)
    contains a key `\"λ_<service_name>\"` (e.g. `\"λ_Regulation_Up\"`) with a `DataFrame` that
    has column `"DateTime"` and one column per bus name, plus `\"horizon_DA\"` giving the number
    of day-ahead steps. Used by [`MerchantHybridCooptimizerCase`](@ref) when ancillary services
    are attached to the hybrid.
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
