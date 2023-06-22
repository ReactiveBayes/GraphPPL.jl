module GraphPPLPlottingExt

using GraphPPL, GraphPlot, Cairo, Compose, MetaGraphsNext

function GraphPPL.plot_graph(g::MetaGraph; file_name = "tmp.png")
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(file_name, 16cm, 16cm), plt)
    return plt
end

GraphPPL.plot_graph(g::GraphPPL.Model; file_name = "tmp.png") = GraphPPL.plot_graph(g.graph; file_name = file_name)

end