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
