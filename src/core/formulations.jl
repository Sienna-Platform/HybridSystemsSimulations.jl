########################### Hybrid Generation Formulations ################################
abstract type AbstractHybridFormulation <: PSI.AbstractDeviceFormulation end
abstract type AbstractHybridFormulationWithReserves <: AbstractHybridFormulation end

"""
    HybridDispatchWithReserves

Device formulation for a hybrid system (single point of common coupling (PCC) with renewable,
thermal, and storage) that participates in both energy and ancillary services markets.
Implements the centralized production cost modeling (PCM) model where the hybrid plant's net
power at the PCC is constrained by ``P_{\\max,\\text{pcc}}`` and ancillary service allocations
(``sb^{\\text{out}}_{p,t}``, ``sb^{\\text{in}}_{p,t}``) are assigned to internal assets (thermal,
renewable, charge, discharge) per the four-quadrant ancillary service model.

Use with a hybrid system in a
[`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) for unit commitment
or economic dispatch.

**Variables:**

  - [`PowerSimulations.ActivePowerOutVariable`](@extref PowerSimulations.ActivePowerOutVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{out}}_t``

  - [`PowerSimulations.ActivePowerInVariable`](@extref PowerSimulations.ActivePowerInVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{in}}_t``

  - [`PowerSimulations.ReservationVariable`](@extref PowerSimulations.ReservationVariable):
    
      + Bounds: {0, 1}
      + Symbol: ``u^{\\text{st}}_t``

  - `ThermalPower`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{th}}``] when on
      + Symbol: ``p^{\\text{th}}_t``

  - [`PowerSimulations.OnVariable`](@extref PowerSimulations.OnVariable):
    
      + Bounds: {0, 1}
      + Symbol: ``u^{\\text{th}}_t``

  - `RenewablePower`:
    
      + Bounds: [0.0, ``P^{*,\\text{re}}_t``]
      + Symbol: ``p^{\\text{re}}_t``

  - `BatteryCharge`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{ch}}``] when charging
      + Symbol: ``p^{\\text{ch}}_t``

  - `BatteryDischarge`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{ds}}``] when discharging
      + Symbol: ``p^{\\text{ds}}_t``

  - [`PowerSimulations.EnergyVariable`](@extref PowerSimulations.EnergyVariable):
    
      + Bounds: [0.0, ``E_{\\max,\\text{st}}``]
      + Symbol: ``e^{\\text{st}}_t``

  - `BatteryStatus`:
    
      + Bounds: {0, 1}
      + Symbol: ``ss^{\\text{st}}_t`` (0 = charge, 1 = discharge)

  - [`ReserveVariableOut`](@ref):
    
      + Bounds: [0.0, ]
      + Symbol: ``sb^{\\text{out}}_t``

  - [`ReserveVariableIn`](@ref):
    
      + Bounds: [0.0, ]
      + Symbol: ``sb^{\\text{in}}_t``

**Time Series Parameters:**

  - `RenewablePowerTimeSeries`: ``P^{*,\\text{re}}_t`` = renewable forecast at time ``t`` (default time series name: `"RenewableDispatch__max_active_power"`)
  - `ElectricLoadTimeSeries`: ``P^{\\text{ld}}_t`` = load consumption at time ``t`` (default time series name: `"PowerLoad__max_active_power"`)

  The canonical mapping is given by
  [`PowerSimulations.get_default_time_series_names`](@extref PowerSimulations.get_default_time_series_names)
  for `PSY.HybridSystem` and `HybridDispatchWithReserves`.

**Data requirements:**

  - **Device:** A [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with at least
    one of: thermal unit (`PowerSystems.get_thermal_unit`), renewable unit
    (`PowerSystems.get_renewable_unit`), storage (`PowerSystems.get_storage`), and optionally
    electric load (`PowerSystems.get_electric_load`). Static limits are read from these
    subcomponents via the `PowerSystems.get_*` accessors listed below.
  - **Time series:** Each hybrid must have forecast time series attached with the default names
    above (or custom names passed when adding parameters).

**Static Parameters:**

  - ``P_{\\max,\\text{pcc}}`` =
    [`PowerSystems.get_output_active_power_limits`](@extref PowerSystems.get_output_active_power_limits)(device).max
  - ``P_{\\max,\\text{th}}`` =
    [`PowerSystems.get_active_power_limits`](@extref PowerSystems.get_active_power_limits)(thermal_unit).max
  - ``P_{\\min,\\text{th}}`` = `PowerSystems.get_active_power_limits(thermal_unit).min`
  - ``P_{\\max,\\text{ch}}`` =
    [`PowerSystems.get_input_active_power_limits`](@extref PowerSystems.get_input_active_power_limits)(storage).max
  - ``P_{\\max,\\text{ds}}`` =
    [`PowerSystems.get_output_active_power_limits`](@extref PowerSystems.get_output_active_power_limits)(storage).max
  - ``\\eta_{\\text{ch}}`` = [`PowerSystems.get_efficiency`](@extref PowerSystems.get_efficiency)(storage).in
  - ``\\eta_{\\text{ds}}`` = `PowerSystems.get_efficiency(storage).out`
  - ``E_{\\max,\\text{st}}`` =
    [`PowerSystems.get_storage_level_limits`](@extref PowerSystems.get_storage_level_limits)(storage).max × capacity
  - ``E^{\\text{st}}_0`` = initial storage energy
  - ``R^{*}_{p,t}`` = ancillary service deployment forecast for service ``p`` at time ``t``
  - ``F_p`` = fraction of ``P_{\\max,\\text{pcc}}`` allowed for service ``p``
  - ``N_p`` = number of periods of compliance for service ``p``

**Expressions:**

Adds ``p^{\\text{out}}_t`` and ``p^{\\text{in}}_t`` to PowerSimulations' `ActivePowerBalance` expression
for use in network balance constraints. When services are present, adds reserve expressions
(`TotalReserveOutUpExpression`, `TotalReserveOutDownExpression`, `TotalReserveInUpExpression`,
`TotalReserveInDownExpression`) and served reserve expressions for tracking deployed reserves.

**Constraints:**

Let ``\\mathcal{T} = \\{1, \\dots, T\\}`` denote the set of time steps.

PCC and status ([`PowerSimulations.InputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.InputActivePowerVariableLimitsConstraint), [`PowerSimulations.OutputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.OutputActivePowerVariableLimitsConstraint), [`StatusOutOn`](@ref), [`StatusInOn`](@ref)):

```math
\\begin{align*}
&  0 \\leq p^{\\text{in}}_t \\leq P_{\\max,\\text{pcc}}, \\quad 0 \\leq p^{\\text{out}}_t \\leq P_{\\max,\\text{pcc}}, \\quad \\forall t \\in \\mathcal{T} \\\\
&  u^{\\text{st}}_t \\in \\{0,1\\} \\quad \\text{(output/input status at PCC)}
\\end{align*}
```

Energy asset balance ([`EnergyAssetBalance`](@ref)):

```math
p^{\\text{th}}_t + p^{\\text{re}}_t + p^{\\text{ds}}_t - p^{\\text{ch}}_t - P^{\\text{ld}}_t = p^{\\text{out}}_t - p^{\\text{in}}_t, \\quad \\forall t \\in \\mathcal{T}
```

Thermal limits ([`ThermalOnVariableUb`](@ref), [`ThermalOnVariableLb`](@ref)):

```math
u^{\\text{th}}_t P_{\\min,\\text{th}} \\leq p^{\\text{th}}_t \\leq u^{\\text{th}}_t P_{\\max,\\text{th}}, \\quad u^{\\text{th}}_t \\in \\{0,1\\}, \\quad \\forall t \\in \\mathcal{T}
```

Renewable limit ([`RenewableActivePowerLimitConstraint`](@ref)):

```math
0 \\leq p^{\\text{re}}_t \\leq P^{*,\\text{re}}_t, \\quad \\forall t \\in \\mathcal{T}
```

Storage charge/discharge status ([`BatteryStatusChargeOn`](@ref), [`BatteryStatusDischargeOn`](@ref)):

```math
\\begin{align*}
&  p^{\\text{ch}}_t \\leq (1 - ss^{\\text{st}}_t) P_{\\max,\\text{ch}}, \\quad p^{\\text{ds}}_t \\leq ss^{\\text{st}}_t P_{\\max,\\text{ds}}, \\quad \\forall t \\in \\mathcal{T} \\\\
&  ss^{\\text{st}}_t \\in \\{0,1\\} \\quad \\text{(0 = charge, 1 = discharge)}
\\end{align*}
```

Storage energy balance ([`BatteryBalance`](@ref)):

```math
e^{\\text{st}}_t = e^{\\text{st}}_{t-1} + \\Delta t \\left( \\eta_{\\text{ch}} p^{\\text{ch}}_t - \\frac{p^{\\text{ds}}_t}{\\eta_{\\text{ds}}} \\right), \\quad \\forall t \\in \\mathcal{T}, \\quad e^{\\text{st}}_0 = E^{\\text{st}}_0
```

When ancillary services are present: [`ThermalReserveLimit`](@ref), [`RenewableReserveLimit`](@ref), [`ChargingReservePowerLimit`](@ref), [`DischargingReservePowerLimit`](@ref), [`ReserveCoverageConstraint`](@ref), [`ReserveCoverageConstraintEndOfPeriod`](@ref), [`HybridReserveAssignmentConstraint`](@ref), [`ReserveBalance`](@ref).

Cycling limits (if `"cycling" => true`), ([`CyclingCharge`](@ref), [`CyclingDischarge`](@ref)):

```math
\\begin{align*}
&  \\eta_{\\text{ch}} \\Delta t \\sum_{t \\in \\mathcal{T}} p^{\\text{ch}}_t \\leq C_{\\text{st}} E_{\\max,\\text{st}} \\\\
&  \\frac{\\Delta t}{\\eta_{\\text{ds}}} \\sum_{t \\in \\mathcal{T}} p^{\\text{ds}}_t \\leq C_{\\text{st}} E_{\\max,\\text{st}}
\\end{align*}
```

End-of-horizon energy target (if `"energy_target" => true`), ([`StateofChargeTargetConstraint`](@ref)):

```math
e^{\\text{st}}_T = E^{\\text{st}}_T
```

Regularization (if `"regularization" => true`): [`ChargeRegularizationConstraint`](@ref), [`DischargeRegularizationConstraint`](@ref).

**Objective:**

Adds cost terms for thermal generation (variable and fixed costs), storage variable O&M,
and penalties for energy target deviations and cycling violations (if enabled).
"""
struct HybridDispatchWithReserves <: AbstractHybridFormulationWithReserves end

"""
    HybridEnergyOnlyDispatch

Device formulation for a hybrid system that participates in energy only (no ancillary
services). Net power at the point of common coupling (PCC) is ``p^{\\text{out}}_t - p^{\\text{in}}_t``
from thermal, renewable, discharge, minus charge and load; subject to ``P_{\\max,\\text{pcc}}``
and asset limits.

**Variables:**

  - [`PowerSimulations.ActivePowerOutVariable`](@extref PowerSimulations.ActivePowerOutVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{out}}_t``

  - [`PowerSimulations.ActivePowerInVariable`](@extref PowerSimulations.ActivePowerInVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{in}}_t``

  - [`PowerSimulations.ReservationVariable`](@extref PowerSimulations.ReservationVariable):
    
      + Bounds: {0, 1}
      + Symbol: ``u^{\\text{st}}_t``

  - `ThermalPower`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{th}}``] when on
      + Symbol: ``p^{\\text{th}}_t``

  - [`PowerSimulations.OnVariable`](@extref PowerSimulations.OnVariable):
    
      + Bounds: {0, 1}
      + Symbol: ``u^{\\text{th}}_t``

  - `RenewablePower`:
    
      + Bounds: [0.0, ``P^{*,\\text{re}}_t``]
      + Symbol: ``p^{\\text{re}}_t``

  - `BatteryCharge`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{ch}}``] when charging
      + Symbol: ``p^{\\text{ch}}_t``

  - `BatteryDischarge`:
    
      + Bounds: [0.0, ``P_{\\max,\\text{ds}}``] when discharging
      + Symbol: ``p^{\\text{ds}}_t``

  - [`PowerSimulations.EnergyVariable`](@extref PowerSimulations.EnergyVariable):
    
      + Bounds: [0.0, ``E_{\\max,\\text{st}}``]
      + Symbol: ``e^{\\text{st}}_t``

  - `BatteryStatus`:
    
      + Bounds: {0, 1}
      + Symbol: ``ss^{\\text{st}}_t`` (0 = charge, 1 = discharge)

**Time Series Parameters:**

  - `RenewablePowerTimeSeries`: ``P^{*,\\text{re}}_t`` = renewable forecast at time ``t`` (default time series name: `"RenewableDispatch__max_active_power"`)
  - `ElectricLoadTimeSeries`: ``P^{\\text{ld}}_t`` = load consumption at time ``t`` (default time series name: `"PowerLoad__max_active_power"`)

  The canonical mapping is given by
  [`PowerSimulations.get_default_time_series_names`](@extref PowerSimulations.get_default_time_series_names)
  for `PSY.HybridSystem` and `HybridEnergyOnlyDispatch`.

**Data requirements:**

  - **Device:** A [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with at least
    one of: thermal unit (`PowerSystems.get_thermal_unit`), renewable unit
    (`PowerSystems.get_renewable_unit`), storage (`PowerSystems.get_storage`), and optionally
    electric load (`PowerSystems.get_electric_load`). Static limits are read from these
    subcomponents via the `PowerSystems.get_*` accessors listed below.
  - **Time series:** Each hybrid must have forecast time series attached with the default names
    above (or custom names passed when adding parameters).

**Static Parameters:**

  - ``P_{\\max,\\text{pcc}}`` =
    [`PowerSystems.get_output_active_power_limits`](@extref PowerSystems.get_output_active_power_limits)(device).max
  - ``P_{\\max,\\text{th}}`` =
    [`PowerSystems.get_active_power_limits`](@extref PowerSystems.get_active_power_limits)(thermal_unit).max
  - ``P_{\\min,\\text{th}}`` = `PowerSystems.get_active_power_limits(thermal_unit).min`
  - ``P_{\\max,\\text{ch}}`` =
    [`PowerSystems.get_input_active_power_limits`](@extref PowerSystems.get_input_active_power_limits)(storage).max
  - ``P_{\\max,\\text{ds}}`` =
    [`PowerSystems.get_output_active_power_limits`](@extref PowerSystems.get_output_active_power_limits)(storage).max
  - ``\\eta_{\\text{ch}}`` = [`PowerSystems.get_efficiency`](@extref PowerSystems.get_efficiency)(storage).in
  - ``\\eta_{\\text{ds}}`` = `PowerSystems.get_efficiency(storage).out`
  - ``E_{\\max,\\text{st}}`` =
    [`PowerSystems.get_storage_level_limits`](@extref PowerSystems.get_storage_level_limits)(storage).max × capacity
  - ``E^{\\text{st}}_0`` = initial storage energy

**Expressions:**

Adds ``p^{\\text{out}}_t`` and ``p^{\\text{in}}_t`` to PowerSimulations' `ActivePowerBalance` expression
for use in network balance constraints.

**Constraints:**

Let ``\\mathcal{T} = \\{1, \\dots, T\\}`` denote the set of time steps.

PCC and status ([`PowerSimulations.InputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.InputActivePowerVariableLimitsConstraint), [`PowerSimulations.OutputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.OutputActivePowerVariableLimitsConstraint), [`StatusOutOn`](@ref), [`StatusInOn`](@ref)):

```math
\\begin{align*}
&  0 \\leq p^{\\text{in}}_t \\leq P_{\\max,\\text{pcc}}, \\quad 0 \\leq p^{\\text{out}}_t \\leq P_{\\max,\\text{pcc}}, \\quad \\forall t \\in \\mathcal{T} \\\\
&  u^{\\text{st}}_t \\in \\{0,1\\} \\quad \\text{(output/input status at PCC)}
\\end{align*}
```

Energy asset balance ([`EnergyAssetBalance`](@ref)):

```math
p^{\\text{th}}_t + p^{\\text{re}}_t + p^{\\text{ds}}_t - p^{\\text{ch}}_t - P^{\\text{ld}}_t = p^{\\text{out}}_t - p^{\\text{in}}_t, \\quad \\forall t \\in \\mathcal{T}
```

Thermal limits ([`ThermalOnVariableUb`](@ref), [`ThermalOnVariableLb`](@ref)):

```math
u^{\\text{th}}_t P_{\\min,\\text{th}} \\leq p^{\\text{th}}_t \\leq u^{\\text{th}}_t P_{\\max,\\text{th}}, \\quad u^{\\text{th}}_t \\in \\{0,1\\}, \\quad \\forall t \\in \\mathcal{T}
```

Renewable limit ([`RenewableActivePowerLimitConstraint`](@ref)):

```math
0 \\leq p^{\\text{re}}_t \\leq P^{*,\\text{re}}_t, \\quad \\forall t \\in \\mathcal{T}
```

Storage charge/discharge status ([`BatteryStatusChargeOn`](@ref), [`BatteryStatusDischargeOn`](@ref)):

```math
\\begin{align*}
&  p^{\\text{ch}}_t \\leq (1 - ss^{\\text{st}}_t) P_{\\max,\\text{ch}}, \\quad p^{\\text{ds}}_t \\leq ss^{\\text{st}}_t P_{\\max,\\text{ds}}, \\quad \\forall t \\in \\mathcal{T} \\\\
&  ss^{\\text{st}}_t \\in \\{0,1\\} \\quad \\text{(0 = charge, 1 = discharge)}
\\end{align*}
```

Storage energy balance ([`BatteryBalance`](@ref)):

```math
e^{\\text{st}}_t = e^{\\text{st}}_{t-1} + \\Delta t \\left( \\eta_{\\text{ch}} p^{\\text{ch}}_t - \\frac{p^{\\text{ds}}_t}{\\eta_{\\text{ds}}} \\right), \\quad \\forall t \\in \\mathcal{T}, \\quad e^{\\text{st}}_0 = E^{\\text{st}}_0
```

Cycling limits (if `"cycling" => true`), ([`CyclingCharge`](@ref), [`CyclingDischarge`](@ref)):

```math
\\begin{align*}
&  \\eta_{\\text{ch}} \\Delta t \\sum_{t \\in \\mathcal{T}} p^{\\text{ch}}_t \\leq C_{\\text{st}} E_{\\max,\\text{st}} \\\\
&  \\frac{\\Delta t}{\\eta_{\\text{ds}}} \\sum_{t \\in \\mathcal{T}} p^{\\text{ds}}_t \\leq C_{\\text{st}} E_{\\max,\\text{st}}
\\end{align*}
```

End-of-horizon energy target (if `"energy_target" => true`), ([`StateofChargeTargetConstraint`](@ref)):

```math
e^{\\text{st}}_T = E^{\\text{st}}_T
```

Regularization (if `"regularization" => true`): [`ChargeRegularizationConstraint`](@ref), [`DischargeRegularizationConstraint`](@ref).

**Objective:**

Adds cost terms for thermal generation (variable and fixed costs), storage variable O&M,
and penalties for energy target deviations and cycling violations (if enabled).
"""
struct HybridEnergyOnlyDispatch <: AbstractHybridFormulation end

"""
    HybridFixedDA

Device formulation for a hybrid system with day-ahead (DA) energy bids/offers fixed;
used in multi-step simulations when the real-time (RT) subproblem is solved with
locked DA positions (e.g. merchant co-optimization with "then vs. now" RT adjustment).

**Variables:**

  - [`PowerSimulations.ActivePowerOutVariable`](@extref PowerSimulations.ActivePowerOutVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{out}}_t``

  - [`PowerSimulations.ActivePowerInVariable`](@extref PowerSimulations.ActivePowerInVariable):
    
      + Bounds: [0.0, ``P_{\\max,\\text{pcc}}``]
      + Symbol: ``p^{\\text{in}}_t``

  - `TotalReserve` (if services present):
    
      + Bounds: [0.0, ]
      + Symbol: total reserve at PCC

**Data requirements:**

  - **Device:** A [`PowerSystems.HybridSystem`](@extref PowerSystems.HybridSystem) with PCC
    limits. Internal asset composition is not modeled in this formulation; only net power at the
    PCC and optional total reserve are used.
  - **Price and horizon data:** Horizon and price data are provided through the merchant
    decision models (e.g. [`MerchantHybridEnergyCase`](@ref),
    [`MerchantHybridCooptimizerCase`](@ref)) using the [`ext` supplemental data
    dictionary](@extref additional_fields) on the system and hybrids as described in their
    docstrings.

**Expressions:**

Adds ``p^{\\text{out}}_t`` and ``p^{\\text{in}}_t`` to PowerSimulations' `ActivePowerBalance` expression
for use in network balance constraints.

**Constraints:**

PCC power limits ([`PowerSimulations.InputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.InputActivePowerVariableLimitsConstraint), [`PowerSimulations.OutputActivePowerVariableLimitsConstraint`](@extref PowerSimulations.OutputActivePowerVariableLimitsConstraint)):

```math
0 \\leq p^{\\text{in}}_t \\leq P_{\\max,\\text{pcc}}, \\quad 0 \\leq p^{\\text{out}}_t \\leq P_{\\max,\\text{pcc}}, \\quad \\forall t \\in \\mathcal{T}
```

When ancillary services are present: [`HybridReserveAssignmentConstraint`](@ref) links component reserves to total reserve at the PCC.
"""
struct HybridFixedDA <: AbstractHybridFormulation end

struct MerchantModelEnergyOnly <: AbstractHybridFormulation end
struct MerchantModelWithReserves <: AbstractHybridFormulationWithReserves end
