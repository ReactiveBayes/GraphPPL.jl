module GraphPPL

using MacroTools
using Static
using NamedTupleTools
using Dictionaries
using BipartiteFactorGraphs
using BipartiteFactorGraphs.Graphs
using MetaGraphsNext, MetaGraphsNext.JLD2
using BitSetTuples

import Base: put!, haskey, getindex, getproperty, setproperty!, setindex!, vec, iterate, showerror, Exception
import BipartiteFactorGraphs.Graphs: neighbors, degree

export as_node, as_variable, as_context, savegraph, loadgraph

# Core components - these have minimal dependencies
include("core/errors.jl")
include("core/functional_indices.jl")
include("core/resizable_array.jl")
include("core/dictionary_key.jl")
include("core/node_creation_options.jl")

# Interfaces - these define the core interfaces for the package
include("interfaces/proxy_label_interface.jl")
include("interfaces/variable_interface.jl")
include("interfaces/edge_interface.jl")
include("interfaces/factor_interface.jl")
include("interfaces/model_interface.jl")
include("interfaces/backend_interface.jl")
include("interfaces/context_interface.jl")
include("interfaces/plugins_interface.jl")
include("interfaces/variable_reference_interface.jl")

# Node data structures (moved from 'nodes/' to 'model/core/')
include("model/core/node_labels.jl")

include("model/core/variable_node_data.jl")
include("model/core/factor_node_data.jl")
include("model/core/anonymous_variable.jl")

include("plugins/plugins_collection.jl")

# Export from core
export NotImplementedError
export FunctionalIndex, FunctionalRange
export AbstractBackend, AbstractInterfaces, AbstractInterfaceAliases

# Export basic node/edge labels
export NodeLabel, EdgeLabel, FactorID

# Basic model structure - needed for context and node creation
include("model/core/indexed_variable.jl")
include("model/core/proxy_label.jl")
# include("model/core/context.jl")
# include("model/core/var_dict.jl")
# include("model/core/variable_ref.jl")
include("model/core/bipartitemodel.jl")

# Model creation components - needed before node properties
include("model/operations/variable_node_creation.jl")

# Node handling - now has proper dependencies
include("model/operations/factor_node_materialization.jl")

# Export from graph
export NodeData, getcontext, getproperties, getextra, is_factor, is_variable

# Export graph modification functions
export set_variable_node_data!, set_factor_node_data!, add_edge_between!
export has_variable_node, has_factor_node, get_variable_node, get_factor_node, has_edge
export add_variable!, add_factor!, add_composite_factor!, connect_nodes!, prune_model!, has_node
export get_node_properties, has_node_property, get_node_property, get_factor_node_name

# Export from nodes
export VariableNodeProperties, FactorNodeProperties
export VariableKindRandom, VariableKindData, VariableKindConstant, VariableKindUnknown
export AnonymousVariable

# Export from model basics
export Model, NodeCreationOptions, Context

# Additional interface types
export StaticInterfaces, StaticInterfaceAliases

# Remaining model components
# include("model/model.jl")
include("model/operations/model_filtering.jl")

# Export additional model components
export VariableRef, IndexedVariable
export path_to_root, factor_nodes, individual_variables, vector_variables, tensor_variables
export VarDict
export ProxyLabel, unroll

include("dsl/macro_utils.jl")

# Plugins
include("plugins/node_created_by.jl")
include("plugins/node_id.jl")
include("plugins/node_tag.jl")
# include("plugins/variational_constraints/variational_constraints.jl")
# include("plugins/meta/meta.jl")

# Model generation
include("generators/model_generator.jl")

# Macros
include("dsl/model_macro.jl")

# Backend
include("backends/default.jl")

"""
    @model function model_name(model_arguments)
        ...
    end

Note that the `@model` macro is not exported by default and the recommended way of using it is 
in the combination with some inference backend. The `GraphPPL` package provides the `DefaultGraphPPLBackend` structure 
for plotting and test purposes, but some backends may specify different behaviour for different structures. For example,
the interface names of a node `Normal` or its behaviour may (and should) depend on the specified backend. 

The recommended way of using the `GraphPPL.@model` macro from other backend-based packages is to define their own 
`@model` macro, which will call the `GraphPPL.model_macro_interior` function with the specified backend. For example 

```julia
module SamplingBasedInference

struct SamplingBasedBackend end

macro model(model_specification)
    return esc(GraphPPL.model_macro_interior(SamplingBasedBackend(), model_specification))
end

end
```

Read more about the backend inteface in the corresponding section of the documentation.

To use `GraphPPL` package as a standalone package for plotting and testing, use the `import GraphPPL: @model` explicitly to add 
the `@model` macro to the current scope. 
"""
macro model(model_specification)
    return esc(GraphPPL.model_macro_interior(DefaultBackend, model_specification))
end

function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if any(x -> x <: VariableRef, argtypes)
                print(io, "\nOne of the arguments to ")
                printstyled(io, "`$(exc.f)`", color = :cyan)
                print(io, " is of type ")
                printstyled(io, "`GraphPPL.VariableRef`", color = :cyan)
                print(io, ". Did you mean to create a new random variable with ")
                printstyled(io, "`:=`", color = :cyan)
                print(io, " operator instead?")
            end
        end
    end
end

end # module
