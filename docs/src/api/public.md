```@meta
CurrentModule = HybridSystemsSimulations
DocTestSetup  = quote
    using HybridSystemsSimulations
end
```

# Public API Reference

```@contents
Pages = ["public.md"]
Depth = 3
```

```@raw html
&nbsp;
&nbsp;
```

## Device Formulations

Device formulations for hybrid systems (single PCC with renewable, thermal, and storage).
Use with [`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) for unit
commitment or economic dispatch.

```@docs
HybridDispatchWithReserves
HybridEnergyOnlyDispatch
HybridFixedDA
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Decision Models

Decision problem types for merchant hybrid participation in day-ahead and real-time markets.

```@docs
MerchantHybridEnergyCase
MerchantHybridEnergyFixedDA
MerchantHybridCooptimizerCase
MerchantHybridBilevelCase
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Variables

### Energy Bids

Day-ahead and real-time energy bid/offer variables at the PCC.

```@docs
EnergyDABidOut
EnergyDABidIn
EnergyRTBidOut
EnergyRTBidIn
```

### Ancillary Service Bids

Day-ahead ancillary service bid/offer variables at the PCC.

```@docs
BidReserveVariableOut
BidReserveVariableIn
```

### Reserve Variables

Reserve quantities allocated to the hybrid's internal assets and total reserve.

```@docs
ReserveVariableOut
ReserveVariableIn
TotalReserve
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Feedforwards

Feedforwards for hybrid storage cycle limits in recurrent simulations.

```@docs
CyclingChargeLimitFeedforward
CyclingDischargeLimitFeedforward
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Constraints

### Dual Optimality Conditions

KKT stationarity constraints for the merchant (lower-level) model; used in bilevel/MPEC formulations.

```@docs
OptConditionThermalPower
OptConditionRenewablePower
OptConditionBatteryCharge
OptConditionBatteryDischarge
OptConditionEnergyVariable
```

### Complementary Slackness

Complementary slackness constraints for MPEC/bilevel reformulation. Each upper-bound (Ub)
constraint has a corresponding lower-bound (Lb) variant.

```@docs
ComplementarySlacknessEnergyAssetBalanceUb
ComplementarySlacknessEnergyAssetBalanceLb
ComplementarySlacknessRenewableActivePowerLimitConstraintUb
```

```@docs; canonical=false
ComplementarySlacknessRenewableActivePowerLimitConstraintLb
```

```@docs
ComplementarySlacknessBatteryStatusDischargeOnUb
ComplementarySlacknessBatteryStatusDischargeOnLb
ComplementarySlacknessBatteryStatusChargeOnUb
ComplementarySlacknessBatteryStatusChargeOnLb
ComplementarySlacknessBatteryBalanceUb
ComplementarySlacknessBatteryBalanceLb
ComplementarySlacknessCyclingCharge
ComplementarySlacknessCyclingDischarge
ComplementarySlacknessEnergyLimitUb
ComplementarySlacknessEnergyLimitLb
```

### Strong Duality

```@docs
StrongDualityCut
```

```@raw html
&nbsp;
&nbsp;
```

* * *

## Parameters

### Objective Function Parameters

Price parameters used in the merchant objective (DA/RT energy and ancillary services).

```@docs
DayAheadEnergyPrice
RealTimeEnergyPrice
AncillaryServicePrice
```

### Variable Value Parameters

Parameters for storage cycle limits (used with feedforwards in recurrent runs).

```@docs
CyclingChargeLimitParameter
CyclingDischargeLimitParameter
```
