# Plugin system

While `GraphPPL` is backend agnostic, specific inference backends might require additional functionality or data saved in nodes. To accommodate these needs, GraphPPL exposes a plugin system that allows users to extend the functionality of the package. Plugins allow the core package to remain lightweight, as well as allowing backend-specific functionality. For example, a node does not need to know by which line of code it was originally created. However, for debugging purposes, it might be useful to save this information in the node. GraphPPL implements a plugin that, when enabled on a model, saves this information in every node. This allows for useful debugging, while switching this functionality off when not needed saves the memory footprint of the model. 

## Creating a plugin

A plugin is a structure that contains a set of functions that are called at specific points in the model creation process. The plugin is implemented with the `preprocess_plugin` and `postprocess_plugin` functions:
```@docs
GraphPPL.preprocess_plugin
GraphPPL.postprocess_plugin
```
Within these functions, the plugin can modify the model, add new nodes, or modify existing nodes. Also, additional data can be passed to nodes in the `preprocess_plugin` function.

## Available plugins

The following plugins are available by default in `GraphPPL`:
- [`GraphPPL.VariationalConstraintsPlugin`](@ref): adds [constraints](@ref constraints-specification) to the model that are used in variational inference.
- [`GraphPPL.MetaPlugin`](@ref): adds arbitrary metadata to nodes in the model.
- [`GraphPPL.NodeCreatedByPlugin`](@ref): adds information about the line of code that created the node. 
- [`GraphPPL.NodeIdPlugin`](@ref): allows attaching an `id` to factor nodes for later inspection.

## Using a plugin

To use a plugin, call the `with_plugins` function when constructing a model:

```@docs 
GraphPPL.with_plugins
```

The `PluginsCollection` is a collection of plugins that will be applied to the model. The order of plugins in the collection is important, as the `preprocess_plugin` and `postprocess_plugin` functions are called in the order of the plugins in the collection.

## Reference 

```@docs 
GraphPPL.UnknownPluginType
GraphPPL.plugin_type
GraphPPL.PluginsCollection
GraphPPL.add_plugin
GraphPPL.VariableNodePlugin
GraphPPL.FactorNodePlugin
GraphPPL.FactorAndVariableNodesPlugin
```