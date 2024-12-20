# [Node tag plugin](@id plugins-node-tag)

GraphPPL provides a built-in plugin to mark factor nodes with a specific tag for later analysis or debugging purposes.

```@docs 
GraphPPL.NodeTagPlugin
```

The plugin allows to specify the `tag` in the `where { ... }` block during the node construction. Here how it works:

```@example plugin-node-tag
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function submodel(y, x, z)
    y ~ Normal(x, z) where { tag = "from submodel" }
end

@model function mainmodel() 
    x ~ Normal(0.0, 1.0)
    z ~ Normal(0.0, 1.0)
    y ~ submodel(x = x, z = z)
end
```

In this example we have created three `Normal` factor nodes and would like to access the one which has been created within the `submodel`.
To do that, we need to instantiate our model with the [`GraphPPL.NodeTagPlugin`](@ref) plugin.

```@example plugin-node-tag
model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        mainmodel(),
        GraphPPL.PluginsCollection(GraphPPL.NodeTagPlugin())
    )
)
nothing #hide
```

After, we can fetch all the nodes with a specific tag using the [`GraphPPL.by_nodetag`](@ref) function.

```@docs
GraphPPL.by_nodetag
```

```@example plugin-node-tag
labels = collect(filter(GraphPPL.by_nodetag("from submodel"), model))
@test all(label -> GraphPPL.getname(label) == Normal, labels) #hide
@test length(labels) === 1 #hide
foreach(labels) do label
    println(GraphPPL.getname(label))
end
nothing #hide
```