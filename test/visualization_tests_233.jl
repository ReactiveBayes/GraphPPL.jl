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

include("../ext/GraphPPLGraphVizExt.jl")  # Include your module

using .GraphPPLGraphVizExt: generate_dot, show_gv, dot_string_to_pdf, SimpleIteration, BFSTraversal

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



@testset "GraphPPLGraphVizExt Tests" begin

    @testset "generate_dot/show_gv Function" begin

        gen_dot_result = generate_dot(
            model_graph = gppl_model,
            # strategy = SimpleIteration(),
            strategy = :simple,
            font_size = 12,
            edge_length = 1.0,
            layout = "neato",
            overlap = false,
            width = 10.0, 
            height = 10.0 
        )

        @test !isempty(gen_dot_result)

        @test typeof(gen_dot_result) == String

        @test occursin("dot\"\"\"\n", gen_dot_result)
        @test occursin("\n\"\"\"", gen_dot_result)

        result = show_gv(gen_dot_result)

        @test result !== nothing

    end

    @testset "get_node_properties Functions" begin

        vertex_labels = collect(labels(meta_graph))

        for (vindex, vlabel) in enumerate(vertex_labels)
            vcode = code_for(meta_graph, vlabel)
            vprops = GraphPPLGraphVizExt.get_node_properties(gppl_model, vcode)

            @test typeof(vprops) == Dict{Symbol, Any}
        end

    end

    @testset "get_namespace_variables_dict Function" begin
        gppl_model_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

        @test length(gppl_model_namespace_dict) == nv(meta_graph)
    end

    @testset "get_sanitized_variable_node_name Function" begin

        model_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

        # match any string - including those with Greek letters - followed by an underscore 
        # and then an integer (excluding 0) followed by a colon and then terminated with 
        # either "nothing" or any floating point value
        var_regex = r"^[a-zA-Z_α-ωΑ-Ω]+_\d{1,}:(nothing|-?\d+\.?\d*([eE][+-]?\d+)?)$"

        for (key, val) in model_namespace_dict
            if haskey(val, :name)
                san_node_name_str = GraphPPLGraphVizExt.get_sanitized_variable_node_name(val)
                # println("VAR: $(san_node_name_str)")
                @test occursin(var_regex, san_node_name_str)
            end
        end
    end

    @testset "get_sanitized_factor_node_name Function" begin

        model_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

        # match any string - including those with Greek letters - followed by an underscore 
        # and then an integer (excluding 0) followed by a colon and then terminated with 
        # either "nothing" or any floating point value
        fac_regex = r"^[a-zA-Z_α-ωΑ-Ω]+_[1-9]\d*$"

        for (key, val) in model_namespace_dict
            if haskey(val, :fform)
                san_node_name_str = GraphPPLGraphVizExt.get_sanitized_factor_node_name(val)
                # println("VAR: $(san_node_name_str)")
                @test san_node_name_str == string(val[:label])
                @test occursin(fac_regex, san_node_name_str)
            end
        end
    end

    @testset "get_sanitized_node_name Function" begin

        model_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

        fac_regex = r"^[a-zA-Z_α-ωΑ-Ω]+_[1-9]\d*$"
        var_regex = r"^[a-zA-Z_α-ωΑ-Ω]+_\d{1,}:(nothing|-?\d+\.?\d*([eE][+-]?\d+)?)$"

        for (key, val) in model_namespace_dict
            san_node_name_str = GraphPPLGraphVizExt.get_sanitized_node_name(val)

            if haskey(val, :fform)
                san_node_name_str = GraphPPLGraphVizExt.get_sanitized_factor_node_name(val)
                # println("VAR: $(san_node_name_str)")
                @test san_node_name_str == string(val[:label])
                @test occursin(fac_regex, san_node_name_str)
            end

            if haskey(val, :name)
                san_node_name_str = GraphPPLGraphVizExt.get_sanitized_variable_node_name(val)
                # println("VAR: $(san_node_name_str)")
                @test occursin(var_regex, san_node_name_str)
            end

        end
    end

    @testset "strip_dot_wrappers Function" begin

        model_namespace_dict = GraphPPLGraphVizExt.get_namespace_variables_dict(gppl_model)

        gen_dot_result = generate_dot(
            model_graph = gppl_model,
            strategy = :simple,
            font_size = 12,
            edge_length = 1.0,
            layout = "neato",
            overlap = false,
            width = 10.0, 
            height = 10.0 
        )

        gen_dot_result_stripped = GraphPPLGraphVizExt.strip_dot_wrappers(gen_dot_result)

        @test !occursin(r"^dot\"\"\"\n" , gen_dot_result_stripped)
        @test !occursin(r"\n\"\"\"$", gen_dot_result_stripped)

    end

    @testset "write_to_dot_file Function" begin

        gen_dot_result = generate_dot(
            model_graph = gppl_model,
            strategy = :simple,
            font_size = 12,
            edge_length = 1.0,
            layout = "neato",
            overlap = false,
            width = 10.0, 
            height = 10.0 
        )

        success = GraphPPLGraphVizExt.write_to_dot_file(gen_dot_result, "test_output.txt")

        if success
            if isfile("test_output.txt")
                rm("test_output.txt")
            end
        end

        @test success == true

    end

end