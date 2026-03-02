abstract type HybridDecisionProblem <: PSI.DecisionProblem end

"""
    MerchantHybridEnergyCase

Decision problem for a merchant hybrid resource that co-optimizes energy bids/offers
in day-ahead and real-time markets only (no ancillary services). The hybrid optimizer
maximizes profit from energy (e.g. DA/RT spread) subject to internal asset limits.
"""
struct MerchantHybridEnergyCase <: HybridDecisionProblem end

"""
    MerchantHybridEnergyFixedDA

Decision problem for a merchant hybrid with fixed day-ahead energy positions; used
when solving the real-time subproblem with locked DA bids/offers.
"""
struct MerchantHybridEnergyFixedDA <: HybridDecisionProblem end

"""
    MerchantHybridCooptimizerCase

Decision problem for a merchant hybrid that co-optimizes energy and ancillary services
in day-ahead and real-time markets. Maximizes ``d'y - c_h' x`` (revenue from bids/offers minus operating cost) subject to
market and asset constraints; ancillary services are committed in DA and fulfilled by internal asset
allocation in RT.
"""
struct MerchantHybridCooptimizerCase <: HybridDecisionProblem end

"""
    MerchantHybridBilevelCase

Decision problem implementing a bilevel formulation for the merchant hybrid
(e.g. upper level: bids/offers, lower level: internal dispatch); used for
equilibrium or regulatory analysis. #TODO DOCS
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
