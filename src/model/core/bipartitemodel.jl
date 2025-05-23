using BipartiteFactorGraphs
import Graphs

"""
    BipartiteModel

Concrete implementation of `FactorGraphModelInterface` using BipartiteFactorGraphs.
"""
struct BipartiteModel{
    TVar,
    TFac,
    E,
    DVars <: AbstractDict{Int, TVar},
    DFacs <: AbstractDict{Int, TFac},
    DE <: AbstractDict{BipartiteFactorGraphs.UnorderedPair{Int}, E},
    C,
    B,
    P,
    S
} <: FactorGraphModelInterface
    graph::BipartiteFactorGraph{TVar, TFac, E, DVars, DFacs, DE}
    context::C
    backend::B
    plugins::P
    source_code::S
end

function create_model(::Type{BipartiteModel}; plugins = nothing, backend = nothing, source = nothing)
    graph = BipartiteFactorGraph(VariableNodeData, FactorNodeData, EdgeData)
    context = Context()
end

function get_context(model::BipartiteModel)
    return model.context
end

function Graphs.nv(model::BipartiteModel)
    return Graphs.nv(model.graph)
end

function Graphs.ne(model::BipartiteModel)
    return Graphs.ne(model.graph)
end

function is_variable_node(model::BipartiteModel, label::NodeLabelInterface)
    return is_variable(model.graph, convert(Int, label))
end

function is_factor_node(model::BipartiteModel, label)
    return is_factor(model.graph, convert(Int, label))
end

function add_variable!(model::BipartiteModel, data::VariableNodeDataInterface)
    return BipartiteFactorGraphs.add_variable!(model.graph, data)
end

function add_factor!(model::BipartiteModel, data::FactorNodeDataInterface)
    return BipartiteFactorGraphs.add_factor!(model.graph, data)
end

function add_edge!(model::BipartiteModel, source::NodeLabelInterface, destination::NodeLabelInterface, edge_data::EdgeInterface)
    return BipartiteFactorGraphs.add_edge!(
        model.graph, __prepare_node_label(model, source), __prepare_node_label(model, destination), edge_data
    )
end

function has_edge(model::BipartiteModel, source, destination)
    return has_edge(model.graph, __prepare_node_label(model, source), __prepare_node_label(model, destination))
end

function get_variables(model::BipartiteModel)
    return BipartiteFactorGraphs.variables(model.graph)
end

function get_factors(model::BipartiteModel)
    return BipartiteFactorGraphs.factors(model.graph)
end

function get_variable_data(model::BipartiteModel, label)
    return BipartiteFactorGraphs.variable_data(model.graph, __prepare_node_label(model, label))
end

function get_factor_data(model::BipartiteModel, label)
    return BipartiteFactorGraphs.factor_data(model.graph, __prepare_node_label(model, label))
end

function get_edge_data(model::BipartiteModel, source, destination)
    return BipartiteFactorGraphs.edge_data(model.graph, __prepare_node_label(model, source), __prepare_node_label(model, destination))
end

function variable_neighbors(model::BipartiteModel, label)
    return BipartiteFactorGraphs.variable_neighbors(model.graph, __prepare_node_label(model, label))
end

function factor_neighbors(model::BipartiteModel, label)
    return BipartiteFactorGraphs.factor_neighbors(model.graph, __prepare_node_label(model, label))
end

function get_backend(model::BipartiteModel)
    return model.backend
end

function get_plugins(model::BipartiteModel)
    return model.plugins
end

function get_source_code(model::BipartiteModel)
    return model.source_code
end

function save_model(file::AbstractString, model::BipartiteModel)
    throw(GraphPPLInterfaceNotImplemented(save_model, BipartiteModel, FactorGraphModelInterface))
end

function load_model(file::AbstractString, ::Type{BipartiteModel})
    throw(GraphPPLInterfaceNotImplemented(load_model, BipartiteModel, FactorGraphModelInterface))
end

function get_variable_node_type(
    ::BipartiteModel{TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
) where {TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
    return TVar
end

function get_factor_node_type(
    ::BipartiteModel{TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
) where {TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
    return TFac
end

function get_edge_data_type(
    ::BipartiteModel{TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
) where {TVar, TFac, E, DVars, DFacs, DE, C, B, P, S}
    return E
end

function __prepare_node_label(model::BipartiteModel, label::NodeLabelInterface)
    return get_id(label)
end