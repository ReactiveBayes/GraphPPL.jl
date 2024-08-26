
include("graphviz_visualization.jl")

using .GPPLGViz

using RxInfer
using Distributions
using Random
using Graphs
using MetaGraphsNext
# using GraphViz
using Dictionaries
using Cairo # necessary for draw PDF...
using Fontconfig # necessary for draw PDF...
using Compose # necessary for draw PDF...

using GraphPlot


# GraphPPL.jl export `@model` macro for model specification
# It accepts a regular Julia function and builds an FFG under the hood
@model function coin_model(y, a, b)
    # We endow θ parameter of our model with some prior
    θ ~ Beta(a, b)
    # or, in this particular case, the `Uniform(0.0, 1.0)` prior also works:
    # θ ~ Uniform(0.0, 1.0)

    # We assume that outcome of each coin flip is governed by the Bernoulli distribution
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

# condition the model on some observed data
conditioned = coin_model(a = 2.0, b = 7.0) | (y = [ true, false, true ], )

# `Create` the actual graph of the model conditioned on the data
rxi_model = RxInfer.create_model(conditioned)

gppl_model = RxInfer.getmodel(rxi_model)

# Extract the MetaGraphsNext graph
meta_graph = gppl_model.graph

# for vertex in MetaGraphsNext.vertices(meta_graph)
# 	println(typeof(vertex))
# end


global_namespace_dicterino = get_namespace_variables_dict(gppl_model)

# println(global_namespace_dicterino)

for (key, val) in global_namespace_dicterino
	san_name = get_sanitized_node_name(val)
	# println("san_name: $(san_name)")
	println("val: $(val)")
end


## GPLOT

# layout=(args...)->spring_layout(args...; C=2)

# draw(
#     PDF(
#         "coin_toss_gplot.pdf", 30cm, 30cm
#     ), GraphPlot.gplot(
#         meta_graph,
#         layout=layout,
#         nodelabel=collect(labels(meta_graph)),
#         nodelabelsize=0.5,
#         NODESIZE=0.05, # diameter of the nodes,
#         nodelabelc="green",
#         nodelabeldist=2.0,
#         nodefillc="blue",
#         edgestrokec="red",
#         EDGELINEWIDTH = 0.8
#     )
# )

## GRAPHVIZ 

# # create the DOT code string
# coin_toss_dot_simple = generate_dot(
#     model_graph = gppl_model, 
#     strategy = SimpleIteration(),
#     font_size = 7,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = true,
#     width = 6.0,
#     height = 6.0
# )

# dot_string_to_pdf(coin_toss_dot_simple, "test_coin_dot_figure.pdf")