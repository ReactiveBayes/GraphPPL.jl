module GraphPPLPlottingExt

using GraphPPL, GraphPlot, Cairo, GraphPlot.Compose

function GraphPlot.gplot(model::GraphPPL.Model; file_name = "tmp.png")
    g = model.graph
    node_labels = [label.name for label in sort(collect(keys(model.mapping)), by = x -> x.global_counter)]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(file_name, 16cm, 16cm), plt)
    return plt
end

function GraphPlot.gplot(model::GraphPPL.Model, around::AbstractArray{GraphPPL.NodeLabel}; depth = 1, file_name = "tmp.png")
    nodes = around
    while depth > 0
        depth -= 1
        for node in nodes
            nodes = unique([nodes; GraphPPL.neighbors(model, node)...])
        end
    end
    nodes = unique(GraphPPL.code_for.(Ref(model.graph), nodes))
    g = first(GraphPPL.induced_subgraph(model.graph, nodes))
    node_labels = [label.name for label in sort(collect(keys(model.mapping)), by = x -> x.global_counter)]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(file_name, 16cm, 16cm), plt)
    return plt
end

GraphPlot.gplot(model::GraphPPL.Model, around::GraphPPL.NodeLabel; kwargs...) = GraphPlot.gplot(model, [around]; kwargs...)

end