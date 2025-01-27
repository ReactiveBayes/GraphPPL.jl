"""
    ModelGenerator(model, kwargs, plugins)

The `ModelGenerator` structure is used to lazily create 
the model with the given `model` and `kwargs` and `plugins`.
"""
struct ModelGenerator{G, K, P, B}
    model::G
    kwargs::K
    plugins::P
    backend::B
end

ModelGenerator(model::G, kwargs::K) where {G, K} = ModelGenerator(model, kwargs, PluginsCollection(), default_backend(model))

getmodel(generator::ModelGenerator) = generator.model
getkwargs(generator::ModelGenerator) = generator.kwargs
getplugins(generator::ModelGenerator) = generator.plugins
getbackend(generator::ModelGenerator) = generator.backend

"""
    with_plugins(generator::ModelGenerator, plugins::PluginsCollection)

Attaches the `plugins` to the `generator`. For example:
```julia
plugins = GraphPPL.PluginsCollection(GraphPPL.NodeCreatedByPlugin())
new_generator = GraphPPL.with_plugins(generator, plugins)
```
"""
function with_plugins(generator::ModelGenerator, plugins::PluginsCollection)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins + plugins, generator.backend)
end

function with_backend(generator::ModelGenerator, backend)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins, backend)
end

function create_model(generator::ModelGenerator)
    return create_model(generator) do model, ctx
        return (;)
    end
end

"""
    create_model([callback], generator::ModelGenerator)

Create a model from the `ModelGenerator`. Accepts an optional callback that can be used to inject extra keyword arguments
into the model creation process by downstream packages. For example:
```jldoctest
using GraphPPL, Distributions

GraphPPL.@model function beta_bernoulli(y, a, b)
    θ ~ Beta(a, b)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

data_for_y = rand(Bernoulli(0.5), 100)

model = GraphPPL.create_model(beta_bernoulli(a = 1, b = 1)) do model, ctx 
    # Inject the data into the model
    y = GraphPPL.datalabel(model, ctx, GraphPPL.NodeCreationOptions(kind = GraphPPL.VariableKindData), :y, data_for_y)
    return (; y = y, )
end

model isa GraphPPL.Model
# output
true
```
"""
function create_model(callback, generator::ModelGenerator)
    model = Model(getmodel(generator), getplugins(generator), getbackend(generator))
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

"""
    source_code(::ModelGenerator, [ extra_args ])

A variant of the `GraphPPL.source_code` that accepts `GraphPPL.ModelGenerator`.
Optionally accepts number of extra arguments in case if `ModelGenerator` does not specify all the input arguments, e.g. `1` (use `GraphPPL.static(1)` for better efficiency).

```jldoctest
julia> import GraphPPL: @model

julia> @model function beta_bernoulli(y)
           θ ~ Beta(1, 1)
           for i in eachindex(y)
               y[i] ~ Bernoulli(θ)
           end
       end

julia> GraphPPL.source_code(beta_bernoulli(y = 1))
@model function beta_bernoulli(y)
    θ ~ Beta(1, 1)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

julia> GraphPPL.source_code(beta_bernoulli(), 1)
@model function beta_bernoulli(y)
    θ ~ Beta(1, 1)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

julia> GraphPPL.source_code(beta_bernoulli(), GraphPPL.static(1))
@model function beta_bernoulli(y)
    θ ~ Beta(1, 1)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end
```
"""
source_code(g::ModelGenerator) = source_code(g, GraphPPL.static(0))
source_code(g::ModelGenerator, extra_args::Integer) = source_code(g, GraphPPL.static(extra_args))
source_code(g::ModelGenerator, extra_args::StaticInt) = model_generator_source_code(g, extra_args + GraphPPL.static(length(getkwargs(g))))

model_generator_source_code(g::ModelGenerator, num_arguments::StaticInt) = source_code(getbackend(g), getmodel(g), num_arguments)