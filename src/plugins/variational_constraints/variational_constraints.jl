export MeanField, BetheFactorization

using TupleTools
using StaticArrays
using Unrolled
using BitSetTuples
using MetaGraphsNext
using DataStructures

"""
    MeanField

Generic factorisation constraint used to specify a mean-field factorisation for recognition distribution `q`.
This constraint ignores `default_constraints` from submodels and forces everything to be factorized.

See also: [`BetheFactorization`](@ref)
"""
struct MeanField end

struct NoConstraints end

include("variational_constraints_macro.jl")
include("variational_constraints_engine.jl")

"""
    VariationalConstraintsPlugin(constraints)

A plugin that adds a VI related properties to the factor node for the variational inference procedure.
"""
struct VariationalConstraintsPlugin{C}
    constraints::C
end

const UnspecifiedConstraints = Constraints((), (), (), (;), (;))

default_constraints(::Any) = UnspecifiedConstraints

"""
    BetheFactorization

Generic factorisation constraint used to specify the Bethe factorisation for recognition distribution `q`.
An alias to `UnspecifiedConstraints`.

See also: [`MeanField`](@ref)
"""
BetheFactorization() = UnspecifiedConstraints

VariationalConstraintsPlugin() = VariationalConstraintsPlugin(NoConstraints())
VariationalConstraintsPlugin(::Nothing) = VariationalConstraintsPlugin(NoConstraints())

GraphPPL.plugin_type(::VariationalConstraintsPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    plugin::VariationalConstraintsPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    preprocess_vi_plugin!(plugin, nodedata, getproperties(nodedata), options)
    return label, nodedata
end

preprocess_vi_plugin!(
    ::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::FactorNodeProperties, options::NodeCreationOptions
) = nothing

function preprocess_vi_plugin!(
    ::VariationalConstraintsPlugin, nodedata::NodeData, nodeproperties::VariableNodeProperties, options::NodeCreationOptions
)
    if haskey(options, :factorized)
        setextra!(nodedata, :factorized, options[:factorized])
    end
    return nothing
end

## Applies the constraints in `constraints` to `model`. This function materializes the constraints in `constraints` and applies them to `model`.
function postprocess_plugin(plugin::VariationalConstraintsPlugin{NoConstraints}, model::Model)
    # Attach `BitSetTuples` according to the number of neighbours of the factor node
    foreach(factor_nodes(model)) do flabel
        nodedata = model[flabel]
        nodeproperties = getproperties(nodedata)
        number_of_neighbours = length(neighbors(nodeproperties))
        setextra!(nodedata, VariationalConstraintsFactorizationBitSetKey, BoundedBitSetTuple(number_of_neighbours))
    end

    apply_constraints!(
        model, GraphPPL.get_principal_submodel(model), GraphPPL.default_constraints(GraphPPL.fform(GraphPPL.getcontext(model)))
    )

    materialize_constraints!(model)
end

## Applies the constraints in `constraints` to `model`. This function materializes the constraints in `constraints` and applies them to `model`.
function postprocess_plugin(plugin::VariationalConstraintsPlugin, model::Model)
    foreach(factor_nodes(model)) do flabel
        nodedata = model[flabel]
        nodeproperties = getproperties(nodedata)
        number_of_neighbours = length(neighbors(nodeproperties))
        setextra!(nodedata, VariationalConstraintsFactorizationBitSetKey, BoundedBitSetTuple(number_of_neighbours))
    end
    apply_constraints!(model, GraphPPL.get_principal_submodel(model), plugin.constraints)
    materialize_constraints!(model)
end
