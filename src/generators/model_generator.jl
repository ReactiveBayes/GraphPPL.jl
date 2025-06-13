"""
    ModelGenerator(model, kwargs, [ plugins ])

The `ModelGenerator` structure is used to lazily create the model with the given `model` and `kwargs` and (optional) `plugins`.

# Fields
- `model`: The model function to be used for creating the graph
- `kwargs`: Named tuple of keyword arguments to be passed to the model
- `plugins`: Collection of plugins to be used (optional)
- `backend`: Backend to be used for model creation (defaults to model's default_backend)
- `source`: Original source code of the model (for debugging purposes)

# Extended Functionality
The ModelGenerator supports several extension methods:

- `with_plugins(generator, plugins)`: Create new generator with updated plugins
- `with_backend(generator, backend)`: Create new generator with different backend
- `with_source(generator, source)`: Create new generator with different source code

# Examples

```jldoctest
julia> import GraphPPL: @model

julia> @model function beta_bernoulli(y)
           θ ~ Beta(1, 1)
           for i = eachindex(y)
               y[i] ~ Bernoulli(θ)
           end
       end

julia> generator = beta_bernoulli(y = rand(10));

julia> struct CustomBackend end

julia> generator_with_backend = GraphPPL.with_backend(generator, CustomBackend());

julia> generator_with_plugins = GraphPPL.with_plugins(generator, GraphPPL.PluginsCollection());

julia> println(GraphPPL.getsource(generator))
function beta_bernoulli(y)
    θ ~ Beta(1, 1)
    for i = eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

julia> generator_with_source = GraphPPL.with_source(generator, "Hello, world!");

julia> println(GraphPPL.getsource(generator_with_source))
Hello, world!
```

See also: [`with_plugins`](@ref), [`with_backend`](@ref), [`with_source`](@ref)
"""
struct ModelGenerator{G, K, P, B, S}
    model::G
    kwargs::K
    plugins::P
    backend::B
    source::S
end

ModelGenerator(model, kwargs) = ModelGenerator(model, kwargs, PluginsCollection())
ModelGenerator(model, kwargs, plugins) = ModelGenerator(model, kwargs, plugins, default_backend(model))
ModelGenerator(model, kwargs, plugins, backend) = ModelGenerator(model, kwargs, plugins, backend, nothing)

get_model(generator::ModelGenerator) = generator.model
get_kwargs(generator::ModelGenerator) = generator.kwargs
get_plugins(generator::ModelGenerator) = generator.plugins
get_backend(generator::ModelGenerator) = generator.backend
get_source(generator::ModelGenerator) = generator.source

"""
    with_plugins(generator::ModelGenerator, plugins::PluginsCollection)

Overwrites the `plugins` specified in the `generator`.
"""
function with_plugins(generator::ModelGenerator, plugins::PluginsCollection)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins + plugins, generator.backend, generator.source)
end

"""
    with_backend(generator::ModelGenerator, plugins::PluginsCollection)

Overwrites the `backend` specified in the `generator`.
"""
function with_backend(generator::ModelGenerator, backend)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins, backend, generator.source)
end

"""
    with_source(generator::ModelGenerator, source)

Overwrites the `source` specified in the `generator`.
"""
function with_source(generator::ModelGenerator, source)
    return ModelGenerator(generator.model, generator.kwargs, generator.plugins, generator.backend, source)
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
    T = get_model_type(get_backend(generator))
    model = create_model(T, plugins = get_plugins(generator), source = get_source(generator), node_strategy = get_backend(generator))
    context = get_context(model)

    extrakwargs = callback(model, context)

    if !(extrakwargs isa NamedTuple)
        error(
            lazy"The return argument from the `ModelGenerator` callback based `create_model` must be a `NamedTuple`. Got $(typeof(extrakwargs)) instead."
        )
    end

    fixedkwargs = get_kwargs(generator)
    fixedkwargskeys = keys(fixedkwargs)

    # if keys intersect
    if any(k -> k ∈ fixedkwargskeys, keys(extrakwargs))
        error("Fixed keys in the `ModelGenerator` should not intersect with the extra keyword arguments in $(extrakwargs).")
    end

    # Construct the interfaces from the provided fixed keyword argument 
    # and the extra keyword arguments obtained from the callback
    interfaces = (; fixedkwargs..., extrakwargs...)

    add_toplevel_model!(model, context, get_model(generator), interfaces)

    return model
end
