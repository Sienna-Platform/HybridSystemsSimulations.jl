# HybridSystemsSimulations.jl Repository Guide

> **Development Guidelines:** Always load [Sienna.md](./Sienna.md) development preferences, style conventions, and best practices for projects using Sienna. Before running tests confirm that the [Sienna.md](./Sienna.md) file has been read.

## Overview

HybridSystemsSimulations.jl is an extension of PowerSimulations.jl (PSI) that provides optimization models for `PowerSystems.HybridSystem` devices: a thermal unit, renewable unit, storage, and/or electric load co-located behind a single point of common coupling (PCC). It is part of the Sienna ecosystem.

The package supports two distinct usage modes:

1. **Device formulations** — model a `HybridSystem` as one device inside a standard PSI `ProblemTemplate` (e.g., a UC or ED problem), dispatching the hybrid's internal assets subject to PCC limits.
2. **Merchant decision models** — custom `PSI.DecisionModel`s (with their own `build_impl!`) that optimize a price-taker hybrid's energy and ancillary-service bids against day-ahead (DA) and real-time (RT) market prices, including a bilevel/KKT formulation.

## Device Formulations

| Formulation | Description |
|---|---|
| `HybridEnergyOnlyDispatch` | Energy-only dispatch of the hybrid's internal assets behind the PCC |
| `HybridDispatchWithReserves` | Dispatch with ancillary-service participation, reserve assignment, and reserve coverage constraints |
| `HybridFixedDA` | Hybrid with fixed day-ahead positions (used downstream of a merchant stage) |

Optional `DeviceModel` attributes: `"cycling"`, `"energy_target"`, `"regularization"`, `"reservation"`.

## Merchant Decision Models

All subtype `HybridDecisionProblem <: PSI.DecisionProblem` and implement custom `PSI.build_impl!`:

| Decision model | Description |
|---|---|
| `MerchantHybridEnergyCase` | DA + RT energy-only bid co-optimization |
| `MerchantHybridEnergyFixedDA` | RT subproblem with locked DA bids |
| `MerchantHybridCooptimizerCase` | DA + RT energy and ancillary-service bid co-optimization |
| `MerchantHybridBilevelCase` | Bilevel formulation (KKT conditions + complementary slackness via SOS1, strong duality) |

A `HybridSystem` must be present in the `System`; the builds error early otherwise.

## Time and Data Conventions (important — easy to get wrong)

- **DA bids are hourly slots; RT variables follow the model resolution.** The DA axis is `merchant_da_time_step_range(container, hybrid)` = `1:min(horizon_hours, DA-series length)`; the variable, parameter, constraint, and objective axes must all use it. RT-to-DA index mapping goes through `merchant_rt_to_da_tmap(rt_len, da_len)` — never hand-roll `div`-based maps.
- **Storage energy quantities are in energy units**, computed as `get_storage_level_limits(storage).{min,max} * get_storage_capacity(storage)`. The same convention applies to initial conditions (`get_initial_storage_capacity_level * capacity`), cycling limits, and `storage_target`. Do not use the bare level fractions.
- **Market prices are hybrid-attached scalar `SingleTimeSeries`**, keyed by name (defaults `"DA"`/`"RT"`, override via `model.ext["day_ahead_time_series_key"]` / `"real_time_time_series_key"`):
  - Energy: `hybrid_energy_price_time_series_name(key)` → `"HybridSystem__energy_price__<key>"`
  - Ancillary: `hybrid_ancillary_service_price_time_series_name(service, key)`
  - Profiles: `"RenewableDispatch__max_active_power"`, `"PowerLoad__max_active_power"`
- `Δt_RT` must come from the container/settings resolution (`PSI.get_resolution`), not from `first(PSY.get_time_series_resolutions(sys))` — systems may carry multiple resolutions and `PSI.validate_time_series!` negotiates the selected one into settings.

## How It Extends PowerSimulations.jl

- **Custom variables**: market bids (`EnergyDABidOut/In`, `EnergyRTBidOut/In`, `BidReserveVariableOut/In`), internal asset variables (`ThermalPower`, `RenewablePower`, `BatteryCharge/Discharge`, `BatteryStatus`), reserves (`TotalReserve`, slacks), and bilevel dual/complementarity variables (`λ`, `μ`, `γ`, `κ`, `ν` families).
- **Custom parameters**: `DayAheadEnergyPrice`, `RealTimeEnergyPrice`, `AncillaryServicePrice`, `CyclingCharge/DischargeLimitParameter`.
- **Feedforwards**: `CyclingChargeLimitFeedforward`, `CyclingDischargeLimitFeedforward` for DA→RT cycling budget coupling.
- **PSI internal overrides** (sensitive to PSI version changes — re-verify on every PSI bump):
  - `PSI.update_decision_state!` for DA bid and reserve variable state (DA bids span one hour of state rows each; all methods clamp to `max_state_index`).
  - `PSI._update_parameter_values!` for hybrid profile/price updates during simulation (guarded by `PSI.get_component_names(attributes)`).
  - `PSI._constituent_cost_expression(::DayAheadEnergyPrice)` — required by PSI's generic `update_variable_cost!`; without it, merchant simulations fail at the first parameter update (not at build).
  - `PSI.validate_time_series!` for `HybridDecisionProblem` (multi-resolution and interval negotiation).
- **Catch discipline**: time-series lookups only swallow `ArgumentError` (`e isa ArgumentError || rethrow()`); container probes use `PSI.has_container_key`, never try/catch.

## Source Layout

```
src/
  core/                              # Type definitions: decision models + time-series keys
                                     #   (decision_models.jl), formulations, variables,
                                     #   aux_variables, constraints, expressions, parameters
  hybrid_system_decision_models.jl   # Decision-state updates, simulation-stage parameter glue
  hybrid_system_device_models.jl     # Variable bounds, initial conditions, device-model attributes
  add_variables.jl                   # Variable constructors (DA axis via merchant_da_time_step_range)
  add_aux_variables.jl               # Cycling usage aux variables
  add_parameters.jl                  # Time-series + price parameters, simulation update overrides
  add_constraints.jl                 # All constraints incl. bilevel KKT/complementary slackness
  objective_function.jl              # Cost terms (Δt- and system-unit-scaled) and PSY5 cost helpers
  feedforwards.jl                    # Cycling limit feedforwards
  decision_models/                   # build_impl! for only_energy, cooptimizer, bilevel cases
  hybrid_system_constructor.jl       # PSI device constructor entry points
```

Respect the include order in `src/HybridSystemsSimulations.jl`: `core/` files are included first; new types/constants go there.

## Dependencies and Compatibility

- Requires PowerSystems 5.x and PowerSimulations 0.36.2+ (`~0.36.2` compat deliberately excludes PSI 0.36.0/0.36.1, which are broken for PowerModels-translated networks with parallel branches — `get_equivalent_physical_branch_parameters` MethodError against PNM 0.23).
- Storage cost access must use PSY5 accessors: `get_charge_variable_cost` / `get_discharge_variable_cost` → `get_vom_cost` → `get_proportional_term`. `StorageCost` has no `variable` field.

## Testing

- Run with `julia --project=test test/runtests.jl` (single testset: append the test file basename, e.g. `test_merchant_sequence`). See Sienna.md for the full test-environment conventions.
- Test systems come from PowerSystemCaseBuilder (RTS GMLC); market price fixtures are the `test/inputs/chuhsi_*` CSVs (hourly, 5-min, and 300/864-step variants). `attach_hybrid_market_time_series!` in `test/test_utils/function_utils.jl` is the single entry point for attaching them — `use_rt_resolution_for_da` switches between hourly-DA and RT-resolution-DA price setups, and both paths must stay covered.
- Merchant tests assert hourly DA axes (e.g., 24 DA bids vs 288 RT bids for a 24 h / 5 min model). Always assert `build!`/`solve!`/`execute!` return statuses, not just result shapes.
- Known modeling caveat: pinning a downstream UC's PCC variables to merchant DA bids via `FixValueFeedforward` is structurally infeasible while merchant DA buy/sell positions can overlap in the same hour (UC's reservation constraint forbids simultaneous in/out). See the note in `test/test_merchant_sequence.jl`.
