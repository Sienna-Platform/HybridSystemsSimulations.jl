### Define Variables using PSI.VariableType
# Energy Bids
"""
    EnergyDABidOut

Variable type for day-ahead energy offer (generating power) at the point of common coupling (PCC).

Docs abbreviation: ``e^{\\text{out}}_{\\text{DA},t} \\in [0, P_{\\max,\\text{pcc}}]`` [MW].
"""
struct EnergyDABidOut <: PSI.VariableType end

"""
    EnergyDABidIn

Variable type for day-ahead energy bid (consuming power) at the point of common coupling (PCC).

Docs abbreviation: ``e^{\\text{in}}_{\\text{DA},t} \\in [0, P_{\\max,\\text{pcc}}]`` [MW].
"""
struct EnergyDABidIn <: PSI.VariableType end

"""
    EnergyRTBidOut

Variable type for real-time energy offer at the point of common coupling (PCC).

Docs abbreviation: ``e^{\\text{out}}_{\\text{RT},t}``. Net RT position with DA locked
is used in the merchant profit expression (e.g. DART spread).
"""
struct EnergyRTBidOut <: PSI.VariableType end

"""
    EnergyRTBidIn

Variable type for real-time energy bid at the point of common coupling (PCC).

Docs abbreviation: ``e^{\\text{in}}_{\\text{RT},t}``.
"""
struct EnergyRTBidIn <: PSI.VariableType end

# Energy Asset Bids
struct EnergyThermalBid <: PSI.VariableType end
struct EnergyRenewableBid <: PSI.VariableType end
struct EnergyBatteryChargeBid <: PSI.VariableType end
struct EnergyBatteryDischargeBid <: PSI.VariableType end

# Ancillary Service Total DA Bids
"""
    BidReserveVariableOut

Variable type for day-ahead ancillary service offer (generation direction) for the
hybrid at the point of common coupling (PCC).

Docs abbreviation: ``sb^{\\text{out}}_{p,t} \\in [0, F_p P_{\\max,\\text{pcc}}]`` for product ``p``.
"""
struct BidReserveVariableOut <: PSI.VariableType end

"""
    BidReserveVariableIn

Variable type for day-ahead ancillary service bid (consumption direction) for the
hybrid at the point of common coupling (PCC).

Docs abbreviation: ``sb^{\\text{in}}_{p,t} \\in [0, F_p P_{\\max,\\text{pcc}}]`` for product ``p``.
"""
struct BidReserveVariableIn <: PSI.VariableType end

# Component Variables
abstract type HybridAssetVariableType <: PSI.VariableType end
struct ThermalPower <: HybridAssetVariableType end
struct RenewablePower <: HybridAssetVariableType end
struct BatteryCharge <: HybridAssetVariableType end
struct BatteryDischarge <: HybridAssetVariableType end
struct BatteryStatus <: HybridAssetVariableType end
struct BatteryEnergyShortageVariable <: PSI.VariableType end
struct BatteryEnergySurplusVariable <: PSI.VariableType end
struct BatteryChargeCyclingSlackVariable <: PSI.VariableType end
struct BatteryDischargeCyclingSlackVariable <: PSI.VariableType end
abstract type BatteryRegularizationVariable <: PSI.VariableType end
struct ChargeRegularizationVariable <: BatteryRegularizationVariable end
struct DischargeRegularizationVariable <: BatteryRegularizationVariable end

# Ancillary Service Variable for Hybrid
abstract type ReserveVariableType <: PSI.VariableType end
abstract type AssetReserveVariableType <: ReserveVariableType end

"""
    ReserveVariableOut

Variable type for ancillary service reserve quantity in the "out" (generation)
direction allocated to the hybrid's internal assets (``sb^{\\text{th}}``, ``sb^{\\text{re}}``, ``sb^{\\text{ds}}``, ``sb^{\\text{ch}}``).
"""
struct ReserveVariableOut <: AssetReserveVariableType end

"""
    ReserveVariableIn

Variable type for ancillary service reserve quantity in the "in" (consumption)
direction allocated to the hybrid's internal assets.
"""
struct ReserveVariableIn <: AssetReserveVariableType end

"""
    TotalReserve

Auxiliary variable type for the total reserve quantity (sum of component reserves)
at the point of common coupling (PCC). Used in reserve balance constraints; not written to results by default.
"""
struct TotalReserve <: AssetReserveVariableType end
struct SlackReserveUp <: PSI.VariableType end
struct SlackReserveDown <: PSI.VariableType end

abstract type ComponentReserveVariableType <: ReserveVariableType end
struct ChargingReserveVariable <: ComponentReserveVariableType end
struct DischargingReserveVariable <: ComponentReserveVariableType end
struct ThermalReserveVariable <: ComponentReserveVariableType end
struct RenewableReserveVariable <: ComponentReserveVariableType end

# Duals for Merchant Model
abstract type MerchantModelDualVariable <: PSI.VariableType end
"""
Internal Merchant Model Devices EnergyAssetBalance Equation Upper Bound Dual
"""
struct λUb <: MerchantModelDualVariable end
"""
Internal Merchant Model Devices EnergyAssetBalance Equation Lower Bound Dual
"""
struct λLb <: MerchantModelDualVariable end
"""
ThermalGeneration Upper Bound Dual
"""
struct μThUb <: MerchantModelDualVariable end
"""
ThermalGeneration Lower Bound Dual
"""
struct μThLb <: MerchantModelDualVariable end
"""
RenewableGeneration Upper Bound Dual
"""
struct μReUb <: MerchantModelDualVariable end
"""
RenewableGeneration Lower Bound Dual
"""
struct μReLb <: MerchantModelDualVariable end
"""
Storage Charge Variable Upper Bound Dual
"""
struct μChUb <: MerchantModelDualVariable end
"""
Storage Charge Variable Lower Bound Dual
"""
struct μChLb <: MerchantModelDualVariable end
"""
Storage Discharge Variable Upper Bound Dual
"""
struct μDsUb <: MerchantModelDualVariable end
"""
Storage Discharge Variable Lower Bound Dual
"""
struct μDsLb <: MerchantModelDualVariable end
"""
Storage Energy Balance Equation Upper Bound Dual
"""
struct γStBalLb <: MerchantModelDualVariable end
"""
Storage Energy Balance Equation Lower Bound Dual
"""
struct γStBalUb <: MerchantModelDualVariable end
"""
Storage Energy Variable Upper Bound Dual
"""
struct νStUb <: MerchantModelDualVariable end
"""
Storage Energy Variable Lower Bound Dual
"""
struct νStLb <: MerchantModelDualVariable end
"""
Storage Discharging Cycling Limit Dual
"""
struct κStDs <: MerchantModelDualVariable end
"""
Storage Charging Cycling Limit Dual
"""
struct κStCh <: MerchantModelDualVariable end

###############################################
##### Complementaty Slackness Variables #####
###############################################
# Names track the constraint types and their Meta Ub and Lb
#! format: off
abstract type MerchantModelComplementarySlackVariable <: PSI.VariableType end
struct ComplementarySlackVarEnergyAssetBalanceUb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarEnergyAssetBalanceLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarThermalOnVariableUb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarThermalOnVariableLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarRenewableActivePowerLimitConstraintUb <: MerchantModelComplementarySlackVariable end
# Not required since RenewableActivePower is lower bounded by 0.0
#struct ComplementarySlackVarRenewableActivePowerLimitConstraintLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarBatteryStatusDischargeOnUb <: MerchantModelComplementarySlackVariable end
# Not required since RenewableActivePower is lower bounded by 0.0
#struct ComplementarySlackVarBatteryStatusDischargeOnLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarBatteryStatusChargeOnUb <: MerchantModelComplementarySlackVariable end
# Not required since RenewableActivePower is lower bounded by 0.0
#struct ComplementarySlackVarBatteryStatusChargeOnLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarBatteryBalanceUb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarBatteryBalanceLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarEnergyLimitUb <: MerchantModelComplementarySlackVariable end
# Not required since RenewableActivePower is lower bounded by 0.0
# struct ComplementarySlackVarEnergyLimitsLb <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarCyclingCharge <: MerchantModelComplementarySlackVariable end
struct ComplementarySlackVarCyclingDischarge <: MerchantModelComplementarySlackVariable end
#! format: on

# implement below
#PSI.convert_result_to_natural_units() = false
PSI.should_write_resulting_value(::Type{TotalReserve}) = false
