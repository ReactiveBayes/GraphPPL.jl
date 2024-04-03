# ["Created by" plugin](@id plugins-node-created-by)

The `@model` macro is capable of saving arbitrary extra metadata information for individual factor nodes upon creation. 
This feature is used by various plugins, one of which is [`GraphPPL.NodeCreatedByPlugin`](@ref).

```@docs
GraphPPL.NodeCreatedByPlugin
```

This plugin saves the expression that has been used to create a particular factor node, which can later be queried, for example, for debugging purposes. 
Here's how it works:

```@example plugins-created-by-example
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function probabilistic_model()
    x ~ Beta(1, 1)
    for i in 1:10
        y[i] ~ Normal(x, 1)
    end
end

model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        probabilistic_model(),
        GraphPPL.PluginsCollection(GraphPPL.NodeCreatedByPlugin())
    )
)
nothing #hide
```

We can now read the `:created_by` extra field for each individual node to see the expression that has created it.
To do that we need to call the [`GraphPPL.getextra`](@ref) on [`GraphPPL.NodeData`](@ref) object with the `:created_by` as the key.

```@example plugins-created-by-example
GraphPPL.factor_nodes(model) do label, nodedata
    println("Node ", label, " has been created by ", GraphPPL.getextra(nodedata, :created_by))
end
@test repr(GraphPPL.getextra(model[GraphPPL.getcontext(model)[Beta, 1]], :created_by)) == "x ~ Beta(1, 1)" #hide
@test all(repr(GraphPPL.getextra(model[GraphPPL.getcontext(model)[Normal, i]], :created_by)) == "y[i] ~ Normal(x, 1)" for i in 1:10) #hide
nothing #hide
```

The nodes correctly identify the expressions, which have created them.

