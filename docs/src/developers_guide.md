# Developers guide

This page is aimed at developers of inference backends who aim to integrate `GraphPPL` into their packages. `GraphPPL` uses the `MetaGraphsNext` package to represent a factor graph model as a graph. In `GraphPPL`, both variables and factors are represented by nodes, and the edges denote the inclusion of variables in factors.

## Model Creation
A model in `GraphPPL` is represented by the `GraphPPL.Model` structure.
```@docs
GraphPPL.Model
```
Models can be indexed with `GraphPPL.NodeLabel` structures, which is a unique identifier of every variable and factor node composed of it's name and a global counter. Every `GraphPPL.NodeLabel` points to a `GraphPPL.VariableNodeData` or `GraphPPL.FactorNodeData`, which contain all relevant information to do Bethe Free Energy minimization in the factor graph. Edges in the graph can be accessed by querying the model with a `NodeLabel` pair of an edge that exists.
## Contexts, Submodels and retrieving NodeLabels
After creating a `GraphPPL.Model` structure, it is important to know about the attached `Context`. The `Context` structure contains all variable and factor nodes in the scope of the model, and contains a `Context` stucture for all submodels. The context of a model can be accessed by the `GraphPPL.getcontext()` function:
```@docs
GraphPPL.getcontext
```

Contexts can be accessed like dictionaries, and will point to `NodeLabel` structures that can be used to query the graph. As a variable with the same name can also live in submodels, we nest the `Context` structures in the same hierarchy as the submodels themselves.

## Variable Creation
Variables in the graph can be created by the `GraphPPL.getorcreate!` function, that takes the model, the context, the name and the index of the variable.
```@docs
GraphPPL.getorcreate!
```

## Applying Constraints

## Piecing everying together
In this section we will create a factor graph from scratch, materializing the underlying factor graph and applying constraints.
First, let's define a model, we'll use the `gcv` model from the Nested Models section:
``` @example dev-guide
using GraphPPL
using Distributions

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
```@example dev-guide
# Create the model
model = GraphPPL.create_model(GraphPPL.with_plugins(gcv(), GraphPPL.VariationalConstraintsPlugin(constraints))) do model, context
    κ = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :κ, nothing)
    ω = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :ω, nothing)
    z = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :z, nothing)
    x = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :x, nothing)
    y = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data, factorized = true), :y, nothing)
end
```
Now we have a fully materialized model that can be passed to an inference engine. To access constraints, we can use the `GraphPPL.factorization_constraint` and `GraphPPL.fform_constraint` functions:
```@docs
GraphPPL.factorization_constraint
GraphPPL.fform_constraint
```
```@example dev-guide
node = context[Normal, 1]
@show GraphPPL.factorization_constraint(model[node])
```