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
  - **Time series:** Default names:

    | Parameter | Default Time Series Name |
    | :--- | :--- |
    | `RenewablePowerTimeSeries` | `"RenewableDispatch__max_active_power"` |
    | `RenewablePowerTimeSeries` (day-ahead-only merchant builds) | `"RenewableDispatch__max_active_power_da"` |
    | `ElectricLoadTimeSeries` | `"PowerLoad__max_active_power"` |
  - **System ext data:** Keys in the
    [`ext` supplemental data dictionary](@extref additional_fields) on
    [`PowerSystems.System`](@extref PowerSystems.System):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | System-level DA table used primarily for its `"DateTime"` axis when deriving horizon windows; bus-price columns are not used for objective pricing. |
    | `"λ_rt_df"` | Yes | System-level RT table used primarily for its `"DateTime"` axis when deriving horizon windows; bus-price columns are not used for objective pricing. |
    | `"horizon_DA"` | Optional | DA index length used during model build; defaults to `length(ext["λ_da_df"][!, "DateTime"])` when omitted. |
    | `"horizon_RT"` | Optional | RT index length used during model build; defaults to `length(ext["λ_rt_df"][!, "DateTime"])` when omitted. |

  - **Hybrid ext data:** Each [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem)
    has its own [`ext` dictionary](@extref additional_fields) with the same keys:

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | Hybrid-level DA price table used for bus-level objective prices and rolling parameter updates. |
    | `"λ_rt_df"` | Yes | Hybrid-level RT price table used for bus-level objective prices and rolling parameter updates. |
    | `"horizon_DA"` | Yes (current implementation) | DA parameter time-step dimension used in parameter construction and updates; also referenced in reserve-assignment constraint logic (e.g., `horizon_DA == 24`). |
    | `"horizon_RT"` | Yes (current implementation) | RT parameter time-step dimension used in parameter construction and updates. |
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
  - **System ext data:** Same key requirements as [`MerchantHybridEnergyCase`](@ref):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | System-level DA table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"λ_rt_df"` | Yes | System-level RT table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"horizon_DA"` | Optional | DA index length used during model build; defaults to table length when omitted. |
    | `"horizon_RT"` | Optional | RT index length used during model build; defaults to table length when omitted. |

  - **Hybrid ext data:** Same key requirements as [`MerchantHybridEnergyCase`](@ref):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | Hybrid-level DA price table used for bus-level objective prices and rolling parameter updates. |
    | `"λ_rt_df"` | Yes | Hybrid-level RT price table used for bus-level objective prices and rolling parameter updates. |
    | `"horizon_DA"` | Yes (current implementation) | DA parameter time-step dimension used in parameter construction and updates; also referenced in reserve-assignment constraint logic (e.g., `horizon_DA == 24`). |
    | `"horizon_RT"` | Yes (current implementation) | RT parameter time-step dimension used in parameter construction and updates. |
"""
struct MerchantHybridEnergyFixedDA <: HybridDecisionProblem end

"""
    MerchantHybridCooptimizerCase

Decision problem for a merchant hybrid that co-optimizes energy and ancillary services
in day-ahead and real-time markets. Maximizes ``d'y - c_h' x`` (revenue from bids/offers minus operating cost) subject to
market and asset constraints; ancillary services are committed in DA and fulfilled by internal asset
allocation in RT.

**Data requirements:**

  - **System:** As for [`MerchantHybridEnergyCase`](@ref). The problem template must include a
    [`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) constructed as
    `DeviceModel(PSY.HybridSystem, HybridDispatchWithReserves)` (or another appropriate hybrid
    formulation with reserves).
  - **Time series:** Default names:

    | Parameter | Default Time Series Name |
    | :--- | :--- |
    | `RenewablePowerTimeSeries` | `"RenewableDispatch__max_active_power"` |
    | `RenewablePowerTimeSeries` (day-ahead-only merchant builds) | `"RenewableDispatch__max_active_power_da"` |
    | `ElectricLoadTimeSeries` | `"PowerLoad__max_active_power"` |
  - **System ext data:** Same key requirements as [`MerchantHybridEnergyCase`](@ref):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | System-level DA table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"λ_rt_df"` | Yes | System-level RT table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"horizon_DA"` | Optional | DA index length used during model build; defaults to table length when omitted. |
    | `"horizon_RT"` | Optional | RT index length used during model build; defaults to table length when omitted. |

  - **Hybrid ext data:** Keys in each hybrid's
    [`ext` dictionary](@extref additional_fields):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | Hybrid-level DA energy price table used for bus-level objective prices and rolling parameter updates. |
    | `"λ_rt_df"` | Yes | Hybrid-level RT energy price table used for bus-level objective prices and rolling parameter updates. |
    | `"horizon_DA"` | Yes (current implementation) | DA parameter time-step dimension used in parameter construction and updates; also referenced in reserve-assignment constraint logic (e.g., `horizon_DA == 24`). |
    | `"horizon_RT"` | Yes (current implementation) | RT parameter time-step dimension used in parameter construction and updates. |
    | `"λ_<service_name>"` | Yes (per attached service) | Ancillary-service DA price table for each attached service (e.g., `"λ_Regulation_Up"`), used in objective pricing with `"DateTime"` and bus columns. |
"""
struct MerchantHybridCooptimizerCase <: HybridDecisionProblem end

"""
    MerchantHybridBilevelCase

Decision problem implementing a bilevel formulation for the merchant hybrid
(e.g. upper level: bids/offers, lower level: internal dispatch); used for
equilibrium or regulatory analysis.

**Data requirements:**

  - **System:** Same as [`MerchantHybridEnergyCase`](@ref) (at least one
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with required forecasts).
  - **Time series:** Default names:

    | Parameter | Default Time Series Name |
    | :--- | :--- |
    | `RenewablePowerTimeSeries` | `"RenewableDispatch__max_active_power"` |
    | `RenewablePowerTimeSeries` (day-ahead-only merchant builds) | `"RenewableDispatch__max_active_power_da"` |
    | `ElectricLoadTimeSeries` | `"PowerLoad__max_active_power"` |
  - **System ext data:** Same key requirements as [`MerchantHybridEnergyCase`](@ref):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | System-level DA table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"λ_rt_df"` | Yes | System-level RT table used primarily for its `"DateTime"` axis when deriving horizon windows. |
    | `"horizon_DA"` | Optional | DA index length used during model build; defaults to table length when omitted. |
    | `"horizon_RT"` | Optional | RT index length used during model build; defaults to table length when omitted. |

  - **Hybrid ext data:** Keys in each hybrid's
    [`ext` dictionary](@extref additional_fields):

    | Key | Required | Description |
    | :--- | :--- | :--- |
    | `"λ_da_df"` | Yes | Hybrid-level DA energy price table used for bus-level objective prices and rolling parameter updates. |
    | `"λ_rt_df"` | Yes | Hybrid-level RT energy price table used for bus-level objective prices and rolling parameter updates. |
    | `"horizon_DA"` | Yes (current implementation) | DA parameter time-step dimension used in parameter construction and updates; also referenced in reserve-assignment constraint logic (e.g., `horizon_DA == 24`). |
    | `"horizon_RT"` | Yes (current implementation) | RT parameter time-step dimension used in parameter construction and updates. |
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
