abstract type HybridDecisionProblem <: PSI.DecisionProblem end

"""
    MerchantHybridEnergyCase

Decision problem for a merchant hybrid resource that co-optimizes energy bids/offers
in day-ahead and real-time markets only (no ancillary services). The hybrid optimizer
maximizes profit from energy (e.g. DA/RT spread) subject to internal asset limits.

**Data requirements:**

  - **System:** A [`PowerSystems.System`](@extref PowerSystems.System) containing at least one
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with the subcomponents
    required by the chosen device formulation (e.g. [`HybridEnergyOnlyDispatch`](@ref)).
  - **Time series:** For each hybrid, forecasts with default names
    `"RenewableDispatch__max_active_power"` (or `"RenewableDispatch__max_active_power_da"` for
    day-ahead-only builds) for renewable capacity and `"PowerLoad__max_active_power"` for load.
  - **System ext data:** Use the
    [`ext` supplemental data dictionary](@extref additional_fields) on
    [`PowerSystems.System`](@extref PowerSystems.System) with keys
    `\"λ_da_df\"` and `\"λ_rt_df\"`, each a `DataFrame` with column `"DateTime"` and one column
    per bus name (matching `PowerSystems.get_name(PowerSystems.get_bus(hybrid))`). Optional
    integer keys `\"horizon_DA\"` and `\"horizon_RT\"` override the number of DA/RT steps
    (defaults: the length of the corresponding `"DateTime"` column).
  - **Hybrid ext data:** Each [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem)
    should have its own [`ext` dictionary](@extref additional_fields) containing the same price
    tables and horizon keys, typically copied from the system-level `ext` before constructing a
    `PowerSimulations.DecisionModel`.
"""
struct MerchantHybridEnergyCase <: HybridDecisionProblem end

"""
    MerchantHybridEnergyFixedDA

Decision problem for a merchant hybrid with fixed day-ahead energy positions; used
when solving the real-time subproblem with locked DA bids/offers.

**Data requirements:**

  - Same [`PowerSystems.System`](@extref PowerSystems.System),
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem), and time-series
    requirements as [`MerchantHybridEnergyCase`](@ref).
  - Same use of the [`ext` supplemental data dictionary](@extref additional_fields) on the
    system and hybrids: keys `\"λ_da_df\"`, `\"λ_rt_df\"`, and optional `\"horizon_DA\"`,
    `\"horizon_RT\"` as described for [`MerchantHybridEnergyCase`](@ref).
"""
struct MerchantHybridEnergyFixedDA <: HybridDecisionProblem end

"""
    MerchantHybridCooptimizerCase

Decision problem for a merchant hybrid that co-optimizes energy and ancillary services
in day-ahead and real-time markets. Maximizes ``d'y - c_h' x`` (revenue from bids/offers minus operating cost) subject to
market and asset constraints; ancillary services are committed in DA and fulfilled by internal asset
allocation in RT.

**Data requirements:**

  - **System and time series:** As for [`MerchantHybridEnergyCase`](@ref). The problem template
    must include a
    [`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) constructed as
    `DeviceModel(PSY.HybridSystem, HybridDispatchWithReserves)` (or another appropriate hybrid
    formulation with reserves).
  - **ext data:** Same use of the [`ext` supplemental data dictionary](@extref additional_fields)
    on the [`PowerSystems.System`](@extref PowerSystems.System) and each
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) as in
    [`MerchantHybridEnergyCase`](@ref), plus per-service price tables for ancillary services
    (see [`AncillaryServicePrice`](@ref)).
"""
struct MerchantHybridCooptimizerCase <: HybridDecisionProblem end

"""
    MerchantHybridBilevelCase

Decision problem implementing a bilevel formulation for the merchant hybrid
(e.g. upper level: bids/offers, lower level: internal dispatch); used for
equilibrium or regulatory analysis.

**Data requirements:**

  - **System and time series:** Same as [`MerchantHybridEnergyCase`](@ref) (at least one
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with required forecasts and
    time-series names).
  - **ext data:** Same use of the [`ext` supplemental data dictionary](@extref additional_fields)
    and keys `\"λ_da_df\"`, `\"λ_rt_df\"`, optional `\"horizon_DA\"`, `\"horizon_RT\"` on the
    system and hybrids as in [`MerchantHybridEnergyCase`](@ref).
"""
struct MerchantHybridBilevelCase <: HybridDecisionProblem end

###############################################################################
# validate_time_series! for HybridDecisionProblem
###############################################################################
# Merchant models (HybridDecisionProblem) use custom builds and get horizon/resolution
# from sys.ext, but the PowerSimulations DecisionModel constructor always calls
# validate_time_series!. We extend it here with checks appropriate for merchant:
# resolution/horizon initialization when UNSET, and forecast_count >= 1 (merchant
# models require PowerSystems forecasts for renewables/loads).

function PSI.validate_time_series!(model::PSI.DecisionModel{<:HybridDecisionProblem})
    sys = PSI.get_system(model)
    settings = PSI.get_settings(model)
    available_resolutions = PSY.get_time_series_resolutions(sys)

    if PSI.get_resolution(settings) == PSI.UNSET_RESOLUTION &&
       length(available_resolutions) != 1
        throw(
            IS.ConflictingInputsError(
                "Data contains multiple resolutions, the resolution keyword argument must be added to the Model. Time Series Resolutions: $(available_resolutions)",
            ),
        )
    elseif PSI.get_resolution(settings) != PSI.UNSET_RESOLUTION &&
           length(available_resolutions) > 1
        if PSI.get_resolution(settings) ∉ available_resolutions
            throw(
                IS.ConflictingInputsError(
                    "Resolution $(PSI.get_resolution(settings)) is not available in the system data. Time Series Resolutions: $(available_resolutions)",
                ),
            )
        end
    else
        PSI.set_resolution!(settings, first(available_resolutions))
    end

    if PSI.get_horizon(settings) == PSI.UNSET_HORIZON
        PSI.set_horizon!(settings, PSY.get_forecast_horizon(sys))
    end

    counts = PSY.get_time_series_counts(sys)
    if counts.forecast_count < 1
        error(
            "The system does not contain forecast data. A DecisionModel can't be built.",
        )
    end
    return
end
