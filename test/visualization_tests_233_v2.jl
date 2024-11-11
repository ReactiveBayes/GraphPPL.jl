using GraphPPL

using Test

using RxInfer
using Distributions
using Random
using Graphs
using MetaGraphsNext
using GraphViz
using Dictionaries

using Cairo
using Fontconfig
using Compose

using GraphPlot

# include("../ext/GraphPPLGraphVizExt.jl") # ??
# using .GraphPPLGraphVizExt: generate_dot, show_gv, dot_string_to_pdf

# Add ext directory to the LOAD_PATH so GraphPPLGraphVizExt can be found
push!(LOAD_PATH, joinpath(@__DIR__, "../ext"))

# using .GraphPPLGraphVizExt: GraphViz  # use the overloaded GraphViz.load
using GraphPPLGraphVizExt: GraphViz  # use the overloaded GraphViz.load and GraphViz.render


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


gen_dot_result_coin_simple = GraphViz.load(
    gppl_model;
    strategy = :simple,
    font_size = 12,
    edge_length = 1.0,
    layout = "neato",
    overlap = false,
    width = 10.0,
    height = 10.0
)

println(gen_dot_result_coin_simple)

# GraphViz.render(gen_dot_result_coin_simple, "test_imgs/coin_model_simple_itr.pdf")


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

# dot_string_to_pdf(gen_dot_result_coin_simple, "test_imgs/coin_model_simple_itr.pdf")
# dot_string_to_pdf(gen_dot_result_coin_bfs, "test_imgs/coin_model_bfs_itr.pdf")