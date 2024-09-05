using Test

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

include("../ext/GraphvizVisualization.jl")  # Include your module

using .GPPLGViz: generate_dot, show_gv, dot_string_to_pdf, SimpleIteration, BFSTraversal

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

# println("typeof(gppl_model): $(typeof(gppl_model))")

@testset "GPPLGViz Tests" begin

    @testset "generate_dot/show_gv" begin

        ## GENERATE DOT
        gen_dot_result = generate_dot(
            model_graph = gppl_model,
            strategy = SimpleIteration(),
            font_size = 12,
            edge_length = 1.0,
            layout = "neato",
            overlap = false,
            width = 10.0, 
            height = 10.0 
        )

        @test !isempty(gen_dot_result)

        # Check if the result is a string
        @test typeof(gen_dot_result) == String

        # Test for specific content in the DOT string
        @test occursin("dot\"\"\"\n", gen_dot_result)
        @test occursin("\n\"\"\"", gen_dot_result)


        ## SHOW GV
        result = show_gv(gen_dot_result)

        # Check that `show_gv` does not return nothing
        @test result !== nothing

    end

    # TEST FOR SHOW GV WAS HERE - ADD MORE TESTS BELOW
    # @testset "show_gv" begin
    #     # Ensure `gen_dot_result` is valid for `show_gv`
    #     @test !isempty(gen_dot_result)

    #     # Test the `show_gv` function
    #     result = show_gv(gen_dot_result)

    #     # Check that `show_gv` does not return nothing
    #     @test result !== nothing

    # end

end