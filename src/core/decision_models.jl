abstract type HybridDecisionProblem <: PSI.DecisionProblem end

const DAY_AHEAD_TIME_SERIES_KEY = "DA"
const REAL_TIME_TIME_SERIES_KEY = "RT"
const HYBRID_TIME_SERIES_FEATURE_KEY = :timeseries_key
const ANCILLARY_PRICE_TIME_SERIES_PREFIX = "HybridSystem__ancillary_service_price__"

"""Scalar energy price time series name for a given user key (e.g. `DAY_AHEAD_TIME_SERIES_KEY`)."""
function hybrid_energy_price_time_series_name(key::AbstractString)
    return "HybridSystem__energy_price__" * string(key)
end

"""
Scalar ancillary price time series name; include the key in the name so DA/RT copies stay
distinct after `transform_single_time_series!` (metadata `features` are not preserved on the
`Deterministic` record in InfrastructureSystems).
"""
function hybrid_ancillary_service_price_time_series_name(
    service_name::AbstractString,
    key::AbstractString = DAY_AHEAD_TIME_SERIES_KEY,
)
    return ANCILLARY_PRICE_TIME_SERIES_PREFIX * string(service_name) * "__" * string(key)
end

"""Match metadata whether the series is still `SingleTimeSeries` or already transformed."""
function first_matching_hybrid_scalar_metadata(
    hybrid::PSY.HybridSystem,
    ts_name::AbstractString,
)
    # Prefer STS metadata because its length matches the scalar series points used by
    # merchant price slicing. DST metadata `count` is the number of forecast windows.
    for T in (IS.SingleTimeSeries, IS.DeterministicSingleTimeSeries)
        try
            return IS.get_time_series_metadata(T, hybrid, string(ts_name))
        catch e
            e isa ArgumentError || rethrow()
        end
    end
    throw(
        ArgumentError(
            "No time series named $(repr(ts_name)) on hybrid $(repr(PSY.get_name(hybrid)))",
        ),
    )
end

time_series_metadata_horizon_steps(metadata::IS.DeterministicMetadata) =
    IS.get_count(metadata)
time_series_metadata_horizon_steps(metadata::IS.SingleTimeSeriesMetadata) =
    IS.get_length(metadata)

"""Integer-safe DA index for each RT step when DA and RT horizons need not divide evenly."""
function merchant_rt_to_da_tmap(rt_len::Int, da_len::Int)
    @assert rt_len >= 1 && da_len >= 1
    return [min(da_len, div((k - 1) * da_len, rt_len) + 1) for k in 1:rt_len]
end

"""Day-ahead energy price indices `1:n_DA` aligned with hourly DA slots and attached DA metadata."""
function merchant_da_time_step_range(
    container::PSI.OptimizationContainer,
    hybrid::PSY.HybridSystem,
)
    da_key = get_day_ahead_time_series_key(container)
    da_metadata = first_matching_hybrid_scalar_metadata(
        hybrid,
        hybrid_energy_price_time_series_name(da_key),
    )
    len_DA_meta = time_series_metadata_horizon_steps(da_metadata)
    settings = PSI.get_settings(container)
    h_ms = Dates.value(PSI.get_horizon(settings))
    # Must use the same unit as `h_ms` (milliseconds); `Dates.value(Hour(1))` is 1, not 3600000.
    da_slot_ms = Dates.value(Dates.Millisecond(Dates.Hour(1)))
    n_DA = max(1, div(h_ms, da_slot_ms))
    return 1:min(n_DA, len_DA_meta)
end

function get_day_ahead_time_series_key(
    model::PSI.DecisionModel{<:HybridDecisionProblem},
)
    return string(get(model.ext, "day_ahead_time_series_key", DAY_AHEAD_TIME_SERIES_KEY))
end

function get_real_time_time_series_key(
    model::PSI.DecisionModel{<:HybridDecisionProblem},
)
    return string(get(model.ext, "real_time_time_series_key", REAL_TIME_TIME_SERIES_KEY))
end

function get_day_ahead_time_series_key(container::PSI.OptimizationContainer)
    ext = PSI.get_ext(PSI.get_settings(container))
    return string(get(ext, "day_ahead_time_series_key", DAY_AHEAD_TIME_SERIES_KEY))
end

function get_real_time_time_series_key(container::PSI.OptimizationContainer)
    ext = PSI.get_ext(PSI.get_settings(container))
    return string(get(ext, "real_time_time_series_key", REAL_TIME_TIME_SERIES_KEY))
end

function set_time_series_keys!(
    container::PSI.OptimizationContainer,
    model::PSI.DecisionModel{<:HybridDecisionProblem},
)
    ext = PSI.get_ext(PSI.get_settings(container))
    ext["day_ahead_time_series_key"] = get_day_ahead_time_series_key(model)
    ext["real_time_time_series_key"] = get_real_time_time_series_key(model)
    return
end

"""
    MerchantHybridEnergyCase

Decision problem for a merchant hybrid resource that co-optimizes energy bids/offers
in day-ahead and real-time markets only (no ancillary services). The hybrid optimizer
maximizes profit from energy (e.g. DA/RT spread) subject to internal asset limits.

**Data requirements:**

  - **System:** A [`PowerSystems.System`](@extref PowerSystems.System) containing at least one
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with the subcomponents
    required by the chosen device formulation (e.g. [`HybridEnergyOnlyDispatch`](@ref)).
  - **Attached scalar time series (each hybrid):** Market prices are bus-selected
    `InfrastructureSystems.SingleTimeSeries` objects with **distinct names** for each logical key
    (defaults `"DA"` / `"RT"`): see [`hybrid_energy_price_time_series_name`](@ref). Profiles use the
    standard renewable/load names below. Override keys via `model.ext["day_ahead_time_series_key"]`
    / `"real_time_time_series_key"` on the [`PowerSimulations.DecisionModel`](@extref).

    | Role | Time series name |
    | :--- | :--- |
    | Day-ahead energy price | [`hybrid_energy_price_time_series_name`](@ref)(`day_ahead_time_series_key`) |
    | Real-time energy price | [`hybrid_energy_price_time_series_name`](@ref)(`real_time_time_series_key`) |
    | Renewable availability | `"RenewableDispatch__max_active_power"` |
    | Electric load | `"PowerLoad__max_active_power"` |

  Horizons, resolutions, and DA↔RT step alignment come from model settings plus series metadata (not
  from `System`/`Hybrid` `ext` DataFrames or `\"λ_*\"` keys).
"""
struct MerchantHybridEnergyCase <: HybridDecisionProblem end

"""
    MerchantHybridEnergyFixedDA

Decision problem for a merchant hybrid with fixed day-ahead energy positions; used
when solving the real-time subproblem with locked DA bids/offers.

**Data requirements:**

  - Same [`PowerSystems.System`](@extref PowerSystems.System),
    [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem), and hybrid-attached
    time-series contract as [`MerchantHybridEnergyCase`](@ref) (keyed scalar DA/RT prices and
    profiles on each hybrid).
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
  - **Hybrid-attached time series:** Same DA/RT keyed energy prices and renewable/load series as
    [`MerchantHybridEnergyCase`](@ref). Additionally, for each ancillary product attached to the
    hybrid, attach a scalar `SingleTimeSeries` named
    [`hybrid_ancillary_service_price_time_series_name`](@ref)(`<service_name>`, `<day_ahead_key>`).
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
  - **Hybrid-attached time series:** Same keyed scalar DA/RT market and profile series as
    [`MerchantHybridEnergyCase`](@ref).
"""
struct MerchantHybridBilevelCase <: HybridDecisionProblem end

###############################################################################
# validate_time_series! for HybridDecisionProblem
###############################################################################
# Merchant models (HybridDecisionProblem) use custom builds; horizons/resolutions follow model
# settings and attached time-series metadata. The PowerSimulations DecisionModel constructor always
# calls validate_time_series!. We extend it here with checks appropriate for merchant:
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

    model_interval = PSI.get_interval(settings)
    available_intervals = Set(
        row.interval for
        row in eachrow(PSY.get_forecast_summary_table(sys)) if row.interval !== nothing
    )
    if model_interval == PSI.UNSET_INTERVAL && length(available_intervals) > 1
        throw(
            IS.ConflictingInputsError(
                "The system contains multiple forecast intervals $(available_intervals). " *
                "The `interval` keyword argument must be provided to the DecisionModel constructor " *
                "to select which interval to use.",
            ),
        )
    elseif model_interval != PSI.UNSET_INTERVAL && !isempty(available_intervals)
        if model_interval ∉ available_intervals
            throw(
                IS.ConflictingInputsError(
                    "Interval $(Dates.canonicalize(model_interval)) is not available in the system data. " *
                    "Available forecast intervals: $(available_intervals)",
                ),
            )
        end
    end
    interval_kwarg =
        model_interval == PSI.UNSET_INTERVAL ? (;) : (; interval = model_interval)
    if PSI.get_horizon(settings) == PSI.UNSET_HORIZON
        PSI.set_horizon!(
            settings,
            PSY.get_forecast_horizon(sys; interval_kwarg...),
        )
    end

    counts = PSY.get_time_series_counts(sys)
    if counts.forecast_count < 1
        error(
            "The system does not contain forecast data. A DecisionModel can't be built.",
        )
    end
    return
end
