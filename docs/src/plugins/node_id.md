# [Node ID plugin](@id plugins-node-id)

GraphPPL provides a built-in plugin to mark factor nodes with a specific ID for later analysis or debugging purposes.

```@docs 
GraphPPL.NodeIdPlugin
```

The plugin allows to specify the `id` in the `where { ... }` block during the node construction. Here how it works:

```@example plugin-node-id
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function submodel(y, x, z)
    y ~ Normal(x, z) where { id = "from submodel" }
end

@model function mainmodel() 
    x ~ Normal(0.0, 1.0)
    z ~ Normal(0.0, 1.0)
    y ~ submodel(x = x, z = z)
end
```

In this example we have created three `Normal` factor nodes and would like to access the one which has been created within the `submodel`.
To do that, we need to instantiate our model with the [`GraphPPL.NodeIdPlugin`](@ref) plugin.

```@example plugin-node-id
model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        mainmodel(),
        GraphPPL.PluginsCollection(GraphPPL.NodeIdPlugin())
    )
)
nothing #hide
```

After, we can fetch all the nodes with a specific id using the [`GraphPPL.by_nodeid`](@ref) function.

```@docs
GraphPPL.by_nodeid
```

```@example plugin-node-id
labels = collect(filter(GraphPPL.by_nodeid("from submodel"), model))
@test all(label -> GraphPPL.getname(label) == Normal, labels) #hide
@test length(labels) === 1 #hide
foreach(labels) do label
    println(GraphPPL.getname(label))
end
nothing #hide
```