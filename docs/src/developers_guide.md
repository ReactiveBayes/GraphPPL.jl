# Developers guide

This page is aimed at developers of inference backends who aim to integrate `GraphPPL` into their packages. `GraphPPL` uses the `MetaGraphsNext` package to represent a factor graph model as a graph. In `GraphPPL`, both variables and factors are represented by nodes, and the edges denote the inclusion of variables in factors.

## Model Creation
A model in `GraphPPL` is represented by the `GraphPPL.Model` structure.
```@docs
GraphPPL.Model
```
Any model is a bipartite graph of variable and factor nodes, with edges denoting which variables are used in which factors. Models can be indexed with `GraphPPL.NodeLabel` structures, which is a unique identifier of every variable and factor node composed of its name and a global counter. Every `GraphPPL.NodeLabel` points to a `GraphPPL.NodeData`, which contains all relevant information to do Bethe Free Energy minimization in the factor graph. Edges in the graph can be accessed by querying the model with a `NodeLabel` pair of an edge that exists. Note that both variable and factor nodes are represented by `GraphPPL.NodeData` structures. To retrieve whether or not a node is a variable or a factor, we can use the `is_variable` and `is_factor` functions:
```@docs
GraphPPL.is_variable
GraphPPL.is_factor
```

!!! note 
    The representation of a `GraphPPL.Model` is a bipartite graph where both variables and factor functions are represented as nodes. The internal representation is therefore not a Forney-style factor graph.

## Contexts, Submodels and retrieving NodeLabels
After creating a `GraphPPL.Model` structure, it is important to know about the attached `Context`. The `Context` structure contains all variable and factor nodes in the scope of the model, and contains a `Context` stucture for all submodels. The context of a model can be accessed by the `GraphPPL.getcontext()` function:
```@docs
GraphPPL.getcontext
```

Contexts can be accessed like dictionaries, and will point to `NodeLabel` structures that can be used to query the graph. As a variable with the same name can also live in submodels, we nest the `Context` structures in the same hierarchy as the submodels themselves. Variables can be retrieved from the Context using a `Symbol`, whereas factors and submodels can be retrieved with their type and index. For example, to access the first `Normal` factor in the context, we can use the following syntax:
``` @example dev-guide-factors
using GraphPPL # hide
using Distributions # hide
import GraphPPL: @model, create_model, getcontext # hide
@model function test_model() # hide
    x ~ Normal(0, 1) # hide
end # hide
model = create_model(test_model()) # hide
context = getcontext(model) # hide

context[Normal, 1]
```

Because on any level, submodels are treated as factors, we can also access submodels in the same way. For example, to access the `Normal` factor in the first submodel, we can use the following syntax:
```julia
context[submodel_name, 1][Normal, 1]
```

## Variable Creation
Variables in the graph can be created by the `GraphPPL.getorcreate!` function, that takes the model, the context, the name and the index of the variable, as well as node creation options (such as additional information that should be saved in nodes).
```@docs
GraphPPL.getorcreate!
```

## Model macro

The `GraphPPL.jl` does not export the `@model` macro by default. For interactive usages (e.g. testing or plotting) `GraphPPL.jl` implements [`GraphPPL.DefaultBackend`](@ref), but any downstream packages must define their own `@model` macro and implement their [custom backend](@ref custom-backend). 

```@example dev-guide
import GraphPPL: @model
```

## Piecing everying together

In this section we will create a factor graph from scratch, materializing the underlying factor graph and applying constraints.
First, let's define a model, we'll use the `gcv` model from the Nested Models section:

```@example dev-guide
using GraphPPL, Distributions

@model function gcv(κ, ω, z, x, y)
    log_σ := κ * z + ω
    σ := exp(log_σ)
    y ~ Normal(x, σ)
end
```
Let's also define a mean-field constraint around the `Normal` node:
``` @example dev-guide
constraints = @constraints begin
    q(x, y, σ) = q(x)q(y)q(σ)
end
```

This defines the `gcv` submodel, but now we have to materialize this model. Let's greate a model and hook up all interfaces to variables that will later have to be supplied by the user.

```@docs
GraphPPL.create_model
```

```@example dev-guide
model = GraphPPL.create_model(GraphPPL.with_plugins(gcv(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(constraints)))) do model, context
    return (;
        κ = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :κ, nothing),
        ω = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :ω, nothing),
        z = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :z, nothing),
        x = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :x, nothing),
        y = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :y, nothing)
    )
end;
```

Now we have a fully materialized model that can be passed to an inference engine. Factorization constraints are saved in two ways: as a tuple of lists of indices of interfaces that represent the individual clusters (e.g. `([1], [2, 3])`) and as a [BoundedBitSetTuple](http://github.com/wouterwln/BitSetTuples.jl). The `BoundedBitSetTuple` is a more efficient way to store the factorization constraints, which stores a `BitMatrix` under the hood representing the factorization clusters. Both can be accessed by the `GraphPPL.getextra` function:

```@example dev-guide
context = GraphPPL.getcontext(model)
node = context[Normal, 1]
@show GraphPPL.getextra(model[node], :factorization_constraint_indices)
@show GraphPPL.getextra(model[node], :factorization_constraint_bitset)
nothing # hide
```

## ResizableArrays

`GraphPPL` uses `ResizableArrays` to store arrays of random variables. A `ResizableArray` is a mutable array that can grow dynamically when data is assigned to it. This is why the `x[i] ~ Normal(0, 1)` syntax is allowed in `GraphPPL`; the `ResizableArray` `x` will check if `i` is a valid index and grow the array if necessary. 
```@docs
GraphPPL.ResizableArray
```
`ResizableArray` is a subtype of `AbstractArray`, and implements all the functions that are expected from an array. Note that `size` returns the largest size of the array across each dimension, so an array of size `(2, 3)` does not necessarily has to have an element stored at index `(2, 3)`, instead there exists a vector of length 3 along the second dimension.

## Model creation engine internal 

```@docs
GraphPPL.Context
GraphPPL.ModelGenerator
GraphPPL.FactorID
GraphPPL.NodeData
GraphPPL.NodeLabel
GraphPPL.EdgeLabel
GraphPPL.ProxyLabel
GraphPPL.Splat
GraphPPL.indexed_last
GraphPPL.lift_index
GraphPPL.datalabel
GraphPPL.StaticInterfaces
GraphPPL.VariableRef
GraphPPL.makevarref
GraphPPL.MissingCollection
GraphPPL.VariableNodeProperties
GraphPPL.FactorNodeProperties
GraphPPL.VarDict
GraphPPL.AnonymousVariable
GraphPPL.NodeDataExtraKey
GraphPPL.IndexedVariable

GraphPPL.VariableKindRandom
GraphPPL.VariableKindData
GraphPPL.VariableKindConstant
GraphPPL.VariableKindUnknown

GraphPPL.Deterministic
GraphPPL.Stochastic
GraphPPL.Atomic
GraphPPL.Composite
GraphPPL.NodeCreationOptions

GraphPPL.variable_nodes
GraphPPL.factor_nodes
GraphPPL.missing_interfaces

GraphPPL.hasextra
GraphPPL.getextra
GraphPPL.setextra!

GraphPPL.make_node!
GraphPPL.add_atomic_factor_node!
GraphPPL.add_toplevel_model!
GraphPPL.add_variable_node!
GraphPPL.add_composite_factor_node!
GraphPPL.copy_markov_blanket_to_child_context
GraphPPL.generate_nodelabel

GraphPPL.FunctionalIndex
GraphPPL.FunctionalRange
```

## Model macro internals

```@docs
GraphPPL.combine_args
GraphPPL.convert_local_statement
GraphPPL.add_get_or_create_expression
GraphPPL.keyword_expressions_to_named_tuple
GraphPPL.convert_anonymous_variables
GraphPPL.is_kwargs_expression
GraphPPL.convert_to_kwargs_expression
GraphPPL.convert_deterministic_statement
GraphPPL.proxy_args
GraphPPL.save_expression_in_tilde
GraphPPL.convert_meta_object
GraphPPL.get_boilerplate_functions
GraphPPL.apply_pipeline_collection
GraphPPL.convert_tilde_expression
GraphPPL.check_reserved_variable_names_model
GraphPPL.generate_get_or_create
GraphPPL.add_meta_construction
GraphPPL.apply_pipeline
GraphPPL.options_vector_to_named_tuple
GraphPPL.get_created_by
GraphPPL.convert_to_anonymous
```

## Auxiliary functionality 

```@docs 
GraphPPL.prune!
```