
"""
    ModelGenerator(model, kwargs, plugins)

The `ModelGenerator` structure is used to lazily create 
the model with the given `model` and `kwargs` and `plugins`.
"""
struct ModelGenerator{G, K, P}
    model::G
    kwargs::K
    plugins::P
end

ModelGenerator(model::G, kwargs::K) where {G, K} = ModelGenerator(model, kwargs, PluginsCollection())

getmodel(generator::ModelGenerator) = generator.model
getkwargs(generator::ModelGenerator) = generator.kwargs
getplugins(generator::ModelGenerator) = generator.plugins

function with_plugins(generator::ModelGenerator, plugins::PluginsCollection)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins + plugins)
end

function create_model(generator::ModelGenerator)
    return create_model(generator) do model, ctx
        return (;)
    end
end

function create_model(callback, generator::ModelGenerator)
    model = create_model(; fform = getmodel(generator), plugins = getplugins(generator))
    context = getcontext(model)

    extrakwargs = callback(model, context)

    if !(extrakwargs isa NamedTuple)
        error(
            lazy"The return argument from the `ModelGenerator` callback based `create_model` must be a `NamedTuple`. Got $(typeof(extrakwargs)) instead."
        )
    end

    fixedkwargs = getkwargs(generator)
    fixedkwargskeys = keys(fixedkwargs)

    # if keys intersect
    if any(k -> k ∈ fixedkwargskeys, keys(extrakwargs))
        error("Fixed keys in the `ModelGenerator` should not intersect with the extra keyword arguments in $(extrakwargs).")
    end

    # Construct the interfaces from the provided fixed keyword argument 
    # and the extra keyword arguments obtained from the callback
    interfaces = (; fixedkwargs..., extrakwargs...)

    add_toplevel_model!(model, context, getmodel(generator), interfaces)

    return model
end
