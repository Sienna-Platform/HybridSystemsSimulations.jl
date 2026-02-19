function _get_time_series(
    container::OptimizationContainer,
    component::PSY.HybridSystem,
    subcomponent::S,
    attributes::TimeSeriesAttributes{T},
) where {S <: PSY.Component, T <: PSY.TimeSeriesData}
    return get_time_series_initial_values!(
        container,
        T,
        component,
        PSY.make_subsystem_time_series_name(subcomponent, get_time_series_name(attributes)),
    )
end

function get_time_series(
    container::OptimizationContainer,
    component::S,
    subcomponent_type::Type{T},
    parameter::TimeSeriesParameter,
    # HSA - 10.02.2024 ---------------
    meta = ISOPT.CONTAINER_KEY_EMPTY_META,
) where {S <: PSY.HybridSystem, T <: PSY.Component}
    parameter_container = get_parameter(container, parameter, S, meta)
    subcomponent = get_subcomponent(component, subcomponent_type)
    return _get_time_series(
        container,
        component,
        subcomponent,
        parameter_container.attributes,
    )
end

function _update_parameter_values!(
    param_array::SparseAxisArray,
    attributes::TimeSeriesAttributes{U},
    ::Type{V},
    model::DecisionModel,
    ::DatasetContainer{InMemoryDataset},
) where {U <: PSY.AbstractDeterministic, V <: PSY.HybridSystem}
    initial_forecast_time = get_current_time(model) # Function not well defined for DecisionModels
    horizon = get_time_steps(get_optimization_container(model))[end]
    multiplier_id = get_time_series_multiplier_id(attributes)
    ts_name = get_time_series_name(attributes)
    components = get_available_components(V, get_system(model))
    ts_uuids = Set{String}()
    for component in components, subcomp_type in [PSY.RenewableGen, PSY.ElectricLoad]
        subcomponent = get_subcomponent(component, subcomp_type)
        !does_subcomponent_exist(component, subcomp_type) && continue
        ss_ts_name = PSY.make_subsystem_time_series_name(subcomponent, ts_name)
        ts_uuid = get_time_series_uuid(U, subcomponent, ss_ts_name)
        if !(ts_uuid in ts_uuids)
            ts_vector = get_time_series_values!(
                U,
                model,
                component,
                ss_ts_name,
                multiplier_id,
                initial_forecast_time,
                horizon,
            )
            for (t, value) in enumerate(ts_vector)
                _set_param_value!(param_array, value, ts_uuid, string(subcomp_type), t)
            end
            push!(ts_uuids, ts_uuid)
        end
    end
end
