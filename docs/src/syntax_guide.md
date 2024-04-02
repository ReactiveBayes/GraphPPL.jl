# [Syntax Guide](@id syntax-guide)

## The `where { meta = ... }` block

Factor nodes can have arbitrary metadata attached to them with the `where { meta = ... }` block after the `~` operator. 
For this functionality to work the [`GraphPPL.MetaPlugin`](@ref) must be enabled.
This metadata can be queried by inference packages to modify the inference procedure.
For example:
```@example where_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b) where { meta = "Hello, world!" }
end

model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        some_model(a = 1, b = 2),
        GraphPPL.PluginsCollection(GraphPPL.MetaPlugin())
    )
)

ctx   = GraphPPL.getcontext(model)
node  = model[ctx[Beta, 1]]

@test GraphPPL.getextra(node, :meta) == "Hello, world!" #hide
GraphPPL.getextra(node, :meta)
```

Other plugins can hook into the `where { ... }` block with the [`GraphPPL.preprocess_plugin`](@ref).

## Tracking the `created_by` field

Factor nodes in the models can optionaly save the expressions with which they were created. For this functionality to 
work the [`GraphPPL.NodeCreatedByPlugin`](@ref) plugin must be enabled.
For example: 

```@example created_by_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b)
    y ~ Beta(x, 1)
end

model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        some_model(a = 1, b = 2),
        GraphPPL.PluginsCollection(GraphPPL.NodeCreatedByPlugin())
    )
)
ctx    = GraphPPL.getcontext(model)
node_1 = model[ctx[Beta, 1]]
node_2 = model[ctx[Beta, 2]]

nothing #hide
```

```@example created_by_syntax
@test repr(GraphPPL.getextra(node_1, :created_by)) == "x ~ Beta(a, b)" #hide
GraphPPL.getextra(node_1, :created_by)
```

```@example created_by_syntax
@test repr(GraphPPL.getextra(node_2, :created_by)) == "y ~ Beta(x, 1)" #hide
GraphPPL.getextra(node_2, :created_by)
```

## The `return` statement

Model can have the return statement inside of them for early stopping. 
The return statement plays no role in [nested models specification](@ref nested-models), however.
The inference packages can also query the return statement of a specific model if needed from its [`GraphPPL.Context`](@ref).

```@example return_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b)
    return "Hello, world!"
end

model = GraphPPL.create_model(some_model(a = 1, b = 2))
ctx   = GraphPPL.getcontext(model)
@test GraphPPL.returnval(ctx) == "Hello, world!" #hide
GraphPPL.returnval(ctx)
```