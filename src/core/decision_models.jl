abstract type HybridDecisionProblem <: PSI.DefaultDecisionProblem end

struct MerchantHybridEnergyCase <: HybridDecisionProblem end
struct MerchantHybridEnergyFixedDA <: HybridDecisionProblem end
struct MerchantHybridCooptimizerCase <: HybridDecisionProblem end
struct MerchantHybridBilevelCase <: HybridDecisionProblem end
