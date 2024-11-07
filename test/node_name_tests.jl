using GraphPPL

using Test

using RxInfer
using Distributions
using Random
using Graphs
using MetaGraphsNext
# using GraphViz
using Dictionaries

using Cairo
using Fontconfig
using Compose

using GraphPlot

include("../ext/GraphPPLGraphVizExt.jl") # ??

using .GraphPPLGraphVizExt: generate_dot, show_gv, dot_string_to_pdf


## CREATE AN RXINFER.JL MODEL:
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


# gen_dot_result_coin_simple = generate_dot(
#     model_graph = gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_coin_bfs = generate_dot(
#     model_graph = gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )


global_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

for vertex in MetaGraphsNext.vertices(meta_graph)

    # index the label of model_namespace_variables with "vertex"
    if haskey(global_namespace_dict[vertex], :name)

        san_node_name_str = GraphPPLGraphVizExt.get_sanitized_variable_node_name(global_namespace_dict[vertex])
        # println("VAR: $(san_node_name_str)")

    elseif haskey(global_namespace_dict[vertex], :fform)

        san_node_name_str = GraphPPLGraphVizExt.get_sanitized_factor_node_name(global_namespace_dict[vertex])
        # println("FAC: $(san_node_name_str)")

    end

    # san_label = GraphPPLGraphVizExt.get_sanitized_node_name(global_namespace_dict[vertex])
	# println(san_label)

	"""
	Check the order of DOT code creation in the case of DOT layout with BFS or simple_iter traversal strat. 
	This may have something to do with the differential visualization. 

    We want {node_id}_{node_name} as the new name for all nodes. 
	"""

end
