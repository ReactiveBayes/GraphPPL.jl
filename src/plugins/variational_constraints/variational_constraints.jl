export MeanField, FullFactorization

using TupleTools
using StaticArrays
using Unrolled
using BitSetTuples
using MetaGraphsNext
using DataStructures
using Memoization

struct MeanField end

struct FullFactorization end

include("variational_constraints_macro.jl")
include("variational_constraints_engine.jl")

"""
    VariationalConstraintsPlugin(constraints)

A plugin that adds a VI related properties to the factor node for the variational inference procedure.
"""
struct VariationalConstraintsPlugin{C}
    constraints::C
end

const EmptyConstraints = @constraints begin end

VariationalConstraintsPlugin() = VariationalConstraintsPlugin(EmptyConstraints)

GraphPPL.plugin_type(::VariationalConstraintsPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    plugin::VariationalConstraintsPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    preprocess_vi_plugin!(plugin, nodedata, getproperties(nodedata))
    return label, nodedata
end

function preprocess_vi_plugin!(::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::FactorNodeProperties)
    # if hasextra(nodedata, :factorization_constraints) || hasextra(nodedata, :factorization_constraints_bitset)
    #     error("Factorizatiom constraints has been already defined for the node ", nodedata, ".")
    # end
    return nothing
end

function preprocess_vi_plugin!(::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::VariableNodeProperties)
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
        setextra!(nodedata, :factorization_constraint_bitset, BitSetTuple(number_of_neighbours))
    end
    apply_constraints!(model, GraphPPL.get_principal_submodel(model), plugin.constraints, ConstraintStack())
    materialize_constraints!(model)
end
