module GraphPPLPlottingExt

using GraphPPL, GraphPlot, Cairo, Compose

function GraphPlot.gplot(model::GraphPPL.Model; file_name = "tmp.png")
    g = model.graph
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(file_name, 16cm, 16cm), plt)
    return plt
end

end