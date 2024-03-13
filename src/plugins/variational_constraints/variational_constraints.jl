export MeanField, BetheFactorization

using TupleTools
using StaticArrays
using Unrolled
using BitSetTuples
using MetaGraphsNext
using DataStructures

struct MeanField end

struct BetheFactorization end

include("variational_constraints_macro.jl")
include("variational_constraints_engine.jl")

"""
    VariationalConstraintsPlugin(constraints)

A plugin that adds a VI related properties to the factor node for the variational inference procedure.
"""
struct VariationalConstraintsPlugin{C}
    constraints::C
end

const EmptyConstraints = UnspecifiedConstraints()

VariationalConstraintsPlugin() = VariationalConstraintsPlugin(EmptyConstraints)
VariationalConstraintsPlugin(::Nothing) = VariationalConstraintsPlugin(EmptyConstraints)

GraphPPL.plugin_type(::VariationalConstraintsPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    plugin::VariationalConstraintsPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    preprocess_vi_plugin!(plugin, nodedata, getproperties(nodedata), options)
    return label, nodedata
end

function preprocess_vi_plugin!(
    ::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::FactorNodeProperties, options::NodeCreationOptions
)
    # if hasextra(nodedata, :factorization_constraints) || hasextra(nodedata, :factorization_constraints_bitset)
    #     error("Factorizatiom constraints has been already defined for the node ", nodedata, ".")
    # end
    return nothing
end

function preprocess_vi_plugin!(
    ::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::VariableNodeProperties, options::NodeCreationOptions
)
    if haskey(options, :factorized)
        setextra!(nodedata, :factorized, options[:factorized])
    end
    # if hasextra(nodedata, :posterior_form_constraint) || hasextra(nodedata, :messages_form_constraint)
    #     error("Functional form constraints have been already defined for the node ", nodedata, ".")
    # end
    return nothing
end

## Applies the constraints in `constraints` to `model`. This function materializes the constraints in `constraints` and applies them to `model`.
function postprocess_plugin(plugin::VariationalConstraintsPlugin, model::Model)
    # Attach `BitSetTuples` according to the number of neighbours of the factor node
    foreach(factor_nodes(model)) do flabel
        nodedata = model[flabel]
        nodeproperties = getproperties(nodedata)
        number_of_neighbours = length(neighbors(nodeproperties))
        setextra!(nodedata, VariationalConstraintsFactorizationBitSetKey, BoundedBitSetTuple(number_of_neighbours))
    end
    apply_constraints!(model, GraphPPL.get_principal_submodel(model), plugin.constraints)
    materialize_constraints!(model)
end
