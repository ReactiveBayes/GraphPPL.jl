# [Visualization](@id visualization)

`GraphPPL.jl` ships with two optional visualization extensions that let you inspect the factor graph of a model. Both are loaded automatically through Julia's package extension mechanism — no explicit `using GraphPPL.Ext...` call is needed. Simply load the relevant packages alongside `GraphPPL`.

## GraphViz extension

The `GraphPPLGraphVizExt` extension is activated when `GraphViz.jl` is loaded alongside `GraphPPL`. It renders the model as a [DOT](https://graphviz.org/doc/info/lang.html)-format graph using GraphViz's layout engines, producing high-quality SVG output that displays inline in notebooks and IDEs.

### Basic usage

```@example visualization-graphviz
using GraphPPL, GraphViz, Distributions
import GraphPPL: @model

@model function coin_toss(x)
    θ ~ Beta(1, 1)
    x .~ Bernoulli(θ)
end

model = GraphPPL.create_model(coin_toss()) do model, context
    return (;
        x = GraphPPL.datalabel(model, context, GraphPPL.NodeCreationOptions(kind = GraphPPL.VariableKindData), :x, [1.0, 0.0, 1.0])
    )
end

GraphViz.load(model; strategy = :simple)
```

The return value is a `GraphVizGraphWrapper`. It renders as SVG in any environment that supports it. The underlying objects are accessible via:
- `viz.graph` — the raw `GraphViz.Graph` object
- `viz.dot_string` — the generated DOT source string

### Saving to a file

To write the visualization to disk as an SVG file, pass a path to `save_to`:

```julia
GraphViz.load(model; strategy = :simple, save_to = "model.svg")
```

### Traversal strategies

The `strategy` keyword controls the order in which nodes and edges are written into the DOT source, which influences how the layout engine positions them.

- **`:simple`** — iterates directly over all vertices and edges. Fast and sufficient for most models.
- **`:bfs`** — traverses the graph breadth-first starting from the first created node. Tends to produce more structured layouts for models with a natural sequential or hierarchical order.

### Visual encoding

The extension distinguishes node types visually:

| Node type     | Shape    | Fill              | Text  |
|:------------- |:-------- |:----------------- |:----- |
| Factor node   | square   | blue (`#4A90D9`)  | white |
| Variable node | circle   | white             | black |

Variable labels are rendered depending on their kind:
- **Constants** — shown as their quoted value (e.g. `"1.0"`)
- **Indexed variables** — rendered with an HTML subscript (e.g. `x₁`)
- **Plain variables** — shown as their quoted name (e.g. `"x"`)

Factor node labels use `GraphPPL.prettyname` on the node's properties.

### Configuration options

| Keyword       | Type                  | Default    | Description                                               |
|:------------- |:--------------------- |:---------- |:--------------------------------------------------------- |
| `strategy`    | `Symbol`              | (required) | Traversal order: `:simple` or `:bfs`                     |
| `layout`      | `String`              | `"dot"`    | GraphViz layout engine (`"dot"`, `"neato"`, `"fdp"`, …)  |
| `font_size`   | `Int`                 | `12`       | Font size for node labels                                 |
| `edge_length` | `Float64`             | `1.0`      | Visual length of edges (interpreted by the layout engine) |
| `overlap`     | `Bool`                | `false`    | Whether nodes are allowed to overlap                      |
| `width`       | `Float64`             | `10.0`     | Canvas width in inches                                    |
| `height`      | `Float64`             | `10.0`     | Canvas height in inches                                   |
| `save_to`     | `String` or `Nothing` | `nothing`  | If set, writes the SVG to this file path                  |

!!! tip
    For dense or large models, try `layout = "fdp"` or `layout = "dot"` combined with `overlap = false` to reduce visual clutter.

## GraphPlot extension

The `GraphPPLPlottingExt` extension activates when both `GraphPlot` and `Cairo` are loaded. It is a lighter-weight alternative that renders the graph through GraphPlot and saves the result as a PNG.

### Basic usage

```@example visualization
using GraphPPL, GraphPlot, Cairo
import GraphPPL: @model
using Distributions

@model function coin_toss(x)
    θ ~ Beta(1, 1)
    x .~ Bernoulli(θ)
end

model = GraphPPL.create_model(coin_toss()) do model, context
    return (;
        x = GraphPPL.datalabel(model, context, GraphPPL.NodeCreationOptions(kind = GraphPPL.VariableKindData), :x, [1.0, 0.0, 1.0])
    )
end

GraphPlot.gplot(model)
```

The plot is saved to `tmp.png` in the current directory and the plot object is returned.

### Local subgraph visualization

For large models it is often more useful to visualize only the neighborhood around a specific node. Pass a `NodeLabel` (or a vector of `NodeLabel`s) and a `depth` to expand the local neighborhood by that many hops:

```julia
# show all nodes within 2 hops of `my_node`
GraphPlot.gplot(model, my_node; depth = 2)
```

This extracts the induced subgraph over the expanded node set and plots only that portion of the factor graph.

| Keyword     | Default     | Description                                    |
|:----------- |:----------- |:---------------------------------------------- |
| `depth`     | `1`         | Number of hops to expand from the seed node(s) |
| `file_name` | `"tmp.png"` | Output PNG file path                           |

!!! note
    The GraphPlot extension does not distinguish factor nodes from variable nodes visually — all nodes are rendered as circles with their label as the name. Use the GraphViz extension for richer visual encoding.

## Choosing an extension

The two extensions serve different purposes:

- Use the **GraphViz extension** when you want publication-quality SVG output, need control over the layout engine, or want nodes color- and shape-coded by type.
- Use the **GraphPlot extension** when you want a quick PNG render or need to zoom into a local neighborhood of the graph using the `depth` parameter.
