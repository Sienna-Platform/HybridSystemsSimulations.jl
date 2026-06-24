# HybridSystemsSimulations.jl — Claude Guide

Platform-wide Sienna conventions (performance, type stability, formatter, environments, code style) live in `.claude/Sienna.md` — read it too. This file is repo-specific and does not restate them.

## Purpose and Place in the Stack

HybridSystemsSimulations.jl (HSS) is an **extension of PowerSimulations.jl (PSI)** that provides optimization formulations for `PowerSystems.HybridSystem` devices: a thermal unit, renewable unit, storage, and/or electric load co-located behind a single point of common coupling (PCC). Direct deps are only `PowerSimulations` and `PowerSystems` (plus JuMP/MOI/DataStructures); it adds no new core abstraction packages — all optimization machinery is inherited from PSI.

Two usage modes:

 1. **Device formulations** — model a `HybridSystem` as one device inside a standard PSI `ProblemTemplate` (UC/ED), dispatching internal assets subject to PCC limits.
 2. **Merchant decision models** — custom `PSI.DecisionModel`s (each with its own `build_impl!`) that optimize a price-taker hybrid's energy and ancillary-service bids against day-ahead (DA) and real-time (RT) market prices, including a bilevel/KKT formulation.

## Device Formulations

| Formulation                  | Description                                                                                         |
|:---------------------------- |:--------------------------------------------------------------------------------------------------- |
| `HybridEnergyOnlyDispatch`   | Energy-only dispatch of the hybrid's internal assets behind the PCC                                 |
| `HybridDispatchWithReserves` | Dispatch with ancillary-service participation, reserve assignment, and reserve coverage constraints |
| `HybridFixedDA`              | Hybrid with fixed day-ahead positions (used downstream of a merchant stage)                         |

Optional `DeviceModel` attributes: `"cycling"`, `"energy_target"`, `"regularization"`, `"reservation"`.

## Merchant Decision Models

All subtype `HybridDecisionProblem <: PSI.DecisionProblem` and implement custom `PSI.build_impl!`:

| Decision model                  | Description                                                                             |
|:------------------------------- |:--------------------------------------------------------------------------------------- |
| `MerchantHybridEnergyCase`      | DA + RT energy-only bid co-optimization                                                 |
| `MerchantHybridEnergyFixedDA`   | RT subproblem with locked DA bids                                                       |
| `MerchantHybridCooptimizerCase` | DA + RT energy and ancillary-service bid co-optimization                                |
| `MerchantHybridBilevelCase`     | Bilevel formulation (KKT conditions + complementary slackness via SOS1, strong duality) |

A `HybridSystem` must be present in the `System`; builds error early otherwise.

## Source Layout

```
src/
  core/                              # Type definitions, included first; new types/constants go here
    decision_models.jl               #   merchant decision-problem types + time-series keys
    formulations.jl                  #   device formulation types
    parameters.jl                    #   parameter types (incl. _constituent_cost_expression hook)
    aux_variables.jl, variables.jl   #   variable + aux-variable types
    constraints.jl, expressions.jl   #   constraint + expression types
  add_to_expression.jl               # add_to_expression! methods
  hybrid_system_decision_models.jl   # decision-state updates, simulation-stage parameter glue
  hybrid_system_device_models.jl     # variable bounds, initial conditions, device-model attributes
  add_variables.jl                   # variable constructors (DA axis via merchant_da_time_step_range)
  add_aux_variables.jl               # cycling-usage aux variables
  add_parameters.jl                  # time-series + price parameters, simulation update overrides
  add_constraints.jl                 # all constraints incl. bilevel KKT/complementary slackness
  objective_function.jl              # cost terms (Δt- and system-unit-scaled) + PSY5 cost helpers
  feedforwards.jl                    # cycling-limit feedforwards
  psy_utils.jl                       # PowerSystems helper accessors
  decision_models/                   # build_impl! for only_energy, cooptimizer, bilevel cases
  hybrid_system_constructor.jl       # PSI device constructor entry points
```

Respect the include order in `src/HybridSystemsSimulations.jl` (above): `core/` files are included first. All exports are declared at the top of the main module file.

## How It Extends PowerSimulations.jl

  - **Custom variables**: market bids (`EnergyDABidOut/In`, `EnergyRTBidOut/In`, `BidReserveVariableOut/In`), internal asset variables (`ThermalPower`, `RenewablePower`, `BatteryCharge/Discharge`, `BatteryStatus`), reserves (`TotalReserve`, `ReserveVariableOut/In`, slacks), and bilevel dual/complementarity variables (`λ`, `μ`, `γ`, `κ`, `ν` families).

  - **Custom parameters**: `DayAheadEnergyPrice`, `RealTimeEnergyPrice`, `AncillaryServicePrice`, `CyclingCharge/DischargeLimitParameter`.
  - **Feedforwards**: `CyclingChargeLimitFeedforward`, `CyclingDischargeLimitFeedforward` for DA→RT cycling-budget coupling.
  - **PSI internal overrides** (sensitive to PSI version changes — re-verify on every PSI bump):
    
      + `PSI.update_decision_state!` for DA bid and reserve variable state (DA bids span one hour of state rows each; methods clamp to `max_state_index`).
      + `PSI._update_parameter_values!` for hybrid profile/price updates during simulation (guarded by `PSI.get_component_names(attributes)`).
      + `PSI._constituent_cost_expression(::DayAheadEnergyPrice)` in `src/core/parameters.jl` — required by PSI's generic `update_variable_cost!`. PSI ≤0.36 only ships methods for `StartupCostParameter`, `ShutdownCostParameter`, `AbstractCostAtMinParameter`; any custom `PSI.ObjectiveFunctionParameter` routed through that path needs its own method (point it at `ProductionCostExpression`). **The MethodError fires at the first simulation parameter update, NOT at build** — it slips through build-only tests, so exercise at least one simulation-update step.
      + `PSI.validate_time_series!` for `HybridDecisionProblem` (multi-resolution and interval negotiation).
  - **Catch discipline**: time-series lookups only swallow `ArgumentError` (`e isa ArgumentError || rethrow()`); container probes use `PSI.has_container_key`, never try/catch.

## Optimization Model Construction Conventions

### `add_*!()` methods must not return collections

Methods that create variables, constraints, or expressions (`add_variables!`, `add_constraints!`, `add_expressions!`, etc.) must always end with a bare `return` (i.e., return `nothing`). They must never return dicts or collections of JuMP objects. Instead, instantiate the appropriate container via `add_*_container!` and store all created objects there.

### Inline expressions when possible

Expression construction should be inlined at the point of use. Only store an expression in a container when it is intended to be reused across multiple constraints or objective terms. Avoid creating expression containers solely as intermediate computation steps.

## Time and Data Conventions (important — easy to get wrong)

  - **DA bids are hourly slots; RT variables follow the model resolution.** The DA axis is `merchant_da_time_step_range(container, hybrid)` = `1:min(horizon_hours, DA-series length)`; the variable, parameter, constraint, and objective axes must all use it. RT-to-DA index mapping goes through `merchant_rt_to_da_tmap(rt_len, da_len)` — never hand-roll `div`-based maps.

  - **Storage energy quantities are in energy units**, computed as `get_storage_level_limits(storage).{min,max} * get_storage_capacity(storage)`. Same convention for initial conditions (`get_initial_storage_capacity_level * capacity`), cycling limits, and `storage_target`. Do not use the bare level fractions.
  - **Market prices are hybrid-attached scalar `SingleTimeSeries`**, keyed by name (defaults `"DA"`/`"RT"`, override via `model.ext["day_ahead_time_series_key"]` / `"real_time_time_series_key"`):
    
      + Energy: `hybrid_energy_price_time_series_name(key)` → `"HybridSystem__energy_price__<key>"`
      + Ancillary: `hybrid_ancillary_service_price_time_series_name(service, key)`
      + Profiles: `"RenewableDispatch__max_active_power"`, `"PowerLoad__max_active_power"`
  - `Δt_RT` must come from the container/settings resolution (`PSI.get_resolution`), not from `first(PSY.get_time_series_resolutions(sys))` — systems may carry multiple resolutions and `PSI.validate_time_series!` negotiates the selected one into settings.

## Dependencies and Compatibility

  - PowerSystems 5.11+, PowerSimulations `~0.36.2` (deliberately excludes PSI 0.36.0/0.36.1, broken for PowerModels-translated networks with parallel branches — `get_equivalent_physical_branch_parameters` MethodError against PNM 0.23). JuMP `^1.28`, Julia `^1.10`.
  - Storage cost access must use PSY5 accessors: `get_charge_variable_cost` / `get_discharge_variable_cost` → `get_vom_cost` → `get_proportional_term`. `StorageCost` has no `variable` field.

## Test / Docs / Formatter Commands (verified)

  - **Tests**: `julia --project=test test/runtests.jl` (single testset: append the test file basename, e.g. `test_merchant_sequence`). Test deps live in `test/Project.toml`. `runtests.jl` runs Aqua checks (`test_unbound_args`, `test_undefined_exports`, `test_ambiguities`) and uses HiGHS as the solver.
  - **Docs**: `julia --project=docs docs/make.jl` (tutorials via `docs/make_tutorials.jl`).
  - **Formatter**: `julia --project=scripts/formatter -e 'include("scripts/formatter/formatter_code.jl")'` (activates and instantiates `scripts/formatter`; formats both `.jl` and `.md`). Run after every task.

## Testing Notes / Gotchas

  - Test systems come from PowerSystemCaseBuilder (RTS GMLC); market price fixtures are the `test/inputs/chuhsi_*` CSVs (hourly, 5-min, and 300/864-step variants). `attach_hybrid_market_time_series!` in `test/test_utils/function_utils.jl` is the single entry point — `use_rt_resolution_for_da` switches between hourly-DA and RT-resolution-DA setups, and both paths must stay covered.
  - Merchant tests assert hourly DA axes (e.g., 24 DA bids vs 288 RT bids for a 24 h / 5 min model). Always assert `build!`/`solve!`/`execute!` return statuses, not just result shapes.
  - Known modeling caveat: pinning a downstream UC's PCC variables to merchant DA bids via `FixValueFeedforward` is structurally infeasible while merchant DA buy/sell positions can overlap in the same hour (UC's reservation constraint forbids simultaneous in/out). See the note in `test/test_merchant_sequence.jl`.
