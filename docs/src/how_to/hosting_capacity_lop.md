# [Calculate hosting capacity for a hybrid system](@id howto_hosting_capacity_lop)

```@meta
CurrentModule = HybridSystemsSimulations
```

How to calculate how much constant, must-serve load ``L_{\mathrm{op}}`` can be added at a single node behind a hybrid
point of common coupling (PCC) using [`HybridHostingCapacityDispatch`](@ref).

## When to use

Use this formulation when you have a [`PowerSystems.System`](@extref) with a
candidate bus and want a single unit commitment / economic-dispatch solve that
**maximizes** constant, must-serve load, ``L_{\mathrm{op}}``, for a
[`PowerSystems.HybridSystem`](@extref) at that bus. The optimal value
``L_{\mathrm{op}}^*`` is reported in MW via [`LOpVariable`](@ref).

Must-serve electric load and PCC import/export rating co-scale with the same
decision (see the [`HybridHostingCapacityDispatch`](@ref) docstring):

```text
P_ld(t) = σ(t) * L_op
0 ≤ p_in(t), p_out(t) ≤ L_op
```

with reservation status using the fixed device-model attribute `"l_op_ub"`
(not ``u \cdot L_{\mathrm{op}}``). Onsite generation and storage nameplates stay
fixed while load and PCC limits move with ``L_{\mathrm{op}}``.

## Prerequisites

  - A [`PowerSystems.System`](@extref) with time series covering the decision
    horizon (this walkthrough uses the modified RTS-GMLC DA system from
    [`PowerSystemCaseBuilder.jl`](https://github.com/Sienna-Platform/PowerSystemCaseBuilder.jl)).
  - An MIP-capable solver (this walkthrough uses [HiGHS](https://jump.dev/JuMP.jl/stable/packages/solvers/#HiGHS.jl)).
  - Device-model attribute `"l_op_ub"` in **SYSTEM_BASE pu** (typically
    `base_power` ``= 100`` MW → ``50`` MW is ``0.5`` pu).
  - Zero renewable curtailment cost when ``L_{\mathrm{op}}`` must dominate the
    objective. [PowerSimulations.jl](https://sienna-platform.github.io/PowerSimulations.jl/stable/)
    minimizes cost; the formulation adds a negative unit benefit on
    ``L_{\mathrm{op}}``, so nonzero curtailment cost can undercut that term.

## Co-located hybrid walkthrough

Wind, combined-cycle gas,
[`EnergyReservoirStorage`](@extref PowerSystems :label:`EnergyReservoirStorage`),
and a [`PowerSystems.PowerLoad`](@extref) behind one PCC at bus `"Chuhsi"` on the
modified RTS-GMLC DA system. Nameplates for onsite renewable / thermal / storage
are **fixed**. Electric load and PCC limits co-scale with ``L_{\mathrm{op}}``.
The walkthrough reuses the existing Clark load from the RTS case (unit-normalized
``\sigma(t)``; see [`HybridHostingCapacityDispatch`](@ref)).

### Load packages and optimizer

```@example hc_colocated
using JuMP
using HiGHS
using PowerSystems
using PowerSimulations
using HybridSystemsSimulations
using PowerSystemCaseBuilder
const PSY = PowerSystems
const PSI = PowerSimulations

optimizer = JuMP.optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 300.0,
    "log_to_console" => false,
)
```

### Build the RTS system

```@example hc_colocated
sys = build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
```

### Zero renewable curtailment cost

```@example hc_colocated
for ren in get_components(RenewableDispatch, sys)
    set_operation_cost!(ren, PSY.RenewableGenerationCost(nothing))
end
```

### Select bus and gather subcomponents

Wind from Chuhsi (317); thermal and load from adjacent Clark (318).

```@example hc_colocated
bus = get_component(Bus, sys, "Chuhsi")
bat = PSY.EnergyReservoirStorage(;
    name = string(bus.number) * "_BATTERY",
    available = true,
    bus = bus,
    prime_mover_type = PSY.PrimeMovers.BA,
    storage_technology_type = PSY.StorageTech.OTHER_CHEM,
    storage_capacity = 4.0,
    storage_level_limits = (min = 0.05, max = 1.0),
    initial_storage_capacity_level = 0.5,
    rating = 2.0,
    active_power = 2.0,
    input_active_power_limits = (min = 0.0, max = 2.0),
    output_active_power_limits = (min = 0.0, max = 2.0),
    efficiency = (in = 0.93, out = 0.93),
    reactive_power = 0.0,
    reactive_power_limits = nothing,
    base_power = 100.0,
    operation_cost = PSY.StorageCost(nothing),
)
renewable = get_component(StaticInjection, sys, "317_WIND_1")
thermal = get_component(StaticInjection, sys, "318_CC_1")
load = get_component(PowerLoad, sys, "Clark")
```

### Construct the hybrid and set ``L_{\mathrm{op}}`` upper bound

`add_component!` copies subcomponent time series onto the hybrid. Device limits
and `"l_op_ub"` are SYSTEM_BASE pu.

```@example hc_colocated
hybrid = PSY.HybridSystem(;
    name = string(bus.number) * "_Hybrid",
    available = true,
    status = true,
    bus = bus,
    active_power = 1.0,
    reactive_power = 0.0,
    base_power = 100.0,
    operation_cost = PSY.MarketBidCost(nothing),
    thermal_unit = thermal,
    electric_load = load,
    storage = bat,
    renewable_unit = renewable,
    interconnection_impedance = 0.0 + 0.0im,
    interconnection_rating = nothing,
    input_active_power_limits = (min = 0.0, max = 10.0),
    output_active_power_limits = (min = 0.0, max = 10.0),
    reactive_power_limits = nothing,
)
add_component!(sys, hybrid)

hybrid = first(get_components(HybridSystem, sys))
l_op_ub_pu = Float64(PSY.get_output_active_power_limits(hybrid).max)
```

### Build the problem template

Register [`HybridHostingCapacityDispatch`](@ref) via a
[`PowerSimulations.DeviceModel`](@extref) on a
[`PowerSimulations.ProblemTemplate`](@extref) with a UC + DC
[`PowerSimulations.NetworkModel`](@extref).

```@example hc_colocated
template = ProblemTemplate(
    NetworkModel(
        DCPPowerModel;
        use_slacks = true,
        duals = [NodalBalanceActiveConstraint],
    ),
)
set_device_model!(template, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template, RenewableNonDispatch, FixedOutput)
set_device_model!(template, PowerLoad, StaticPowerLoad)
set_device_model!(template, Line, StaticBranch)
set_device_model!(template, TapTransformer, StaticBranchUnbounded)
set_service_model!(template, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
set_service_model!(template, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))

set_device_model!(
    template,
    DeviceModel(
        PSY.HybridSystem,
        HybridHostingCapacityDispatch;
        attributes = Dict{String, Any}(
            "l_op_ub" => l_op_ub_pu,
            "cycling" => false,
            "regularization" => false,
            "reservation" => true,
            "energy_target" => false,
        ),
    ),
)
```

### Solve and read ``L_{\mathrm{op}}``

Build and solve a
[`DecisionModel`](@extref PowerSimulations :label:`DecisionModel`), then read
[`LOpVariable`](@ref) (values are in MW).

```@example hc_colocated
model = DecisionModel(
    template,
    sys;
    optimizer = optimizer,
    store_variable_names = true,
)
output_dir = mktempdir(; cleanup = true) #hide
PSI.build!(model; output_dir = output_dir)
PSI.solve!(model)

res = PSI.OptimizationProblemResults(model)
lop_df = PSI.read_variable(res, "LOpVariable__HybridSystem")
lop_mw = Float64(first(lop_df[!, :value]))
lop_mw
```
