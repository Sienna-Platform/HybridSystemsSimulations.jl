########################### Hybrid Generation Formulations ################################
abstract type AbstractHybridFormulation <: PSI.AbstractDeviceFormulation end
abstract type AbstractHybridFormulationWithReserves <: AbstractHybridFormulation end

"""
    HybridDispatchWithReserves

Device formulation for a hybrid system (single PCC with renewable, thermal, and storage)
that participates in both energy and ancillary service (AS) markets. Implements the
centralized PCM model where the hybrid plant's net power at the PCC is constrained by
``P_{\\max,\\text{pcc}}`` and AS allocations (``sb^{\\text{out}}_{p,t}``, ``sb^{\\text{in}}_{p,t}``) are assigned to internal assets
(thermal, renewable, charge, discharge) per the four-quadrant AS model.

Use with a hybrid system in a
[`PowerSimulations.DeviceModel`](@extref PowerSimulations.DeviceModel) for unit commitment
or economic dispatch.
"""
struct HybridDispatchWithReserves <: AbstractHybridFormulationWithReserves end

"""
    HybridEnergyOnlyDispatch

Device formulation for a hybrid system that participates in energy only (no ancillary
services). Net power at the PCC is ``p^{\\text{out}}_t - p^{\\text{in}}_t`` from thermal, renewable, discharge,
minus charge and load; subject to ``P_{\\max,\\text{pcc}}`` and asset limits.
"""
struct HybridEnergyOnlyDispatch <: AbstractHybridFormulation end

"""
    HybridFixedDA

Device formulation for a hybrid system with day-ahead (DA) energy bids/offers fixed;
used in multi-step simulations when the real-time (RT) subproblem is solved with
locked DA positions (e.g. merchant co-optimization with "then vs. now" RT adjustment).
"""
struct HybridFixedDA <: AbstractHybridFormulation end

struct MerchantModelEnergyOnly <: AbstractHybridFormulation end
struct MerchantModelWithReserves <: AbstractHybridFormulationWithReserves end
