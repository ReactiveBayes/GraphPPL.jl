@testitem "Model visualizations with GraphViz: generate DOT and save to file" begin
    using GraphPPL, Distributions, GraphViz

    include("../testutils.jl")

    # test params for layout and strategy combinations
    layouts = ["dot", "neato"]
    strategies = [:bfs, :simple]

    test_imgs_path = joinpath(@__DIR__, "graphviz_test_imgs") #gitignored
    if !isdir(test_imgs_path)
        mkdir(test_imgs_path)
    end

    import .TestUtils.ModelZoo as A

    # for all models in the models zoo
    for model in TestUtils.ModelZoo.ModelsInTheZooWithoutArguments
        # for each combination of layout and strategy
        for gv_layout in layouts
            for gv_strategy in strategies
                model_name = string(model)
                test_imgs_name = string(model_name, "_", gv_strategy, "_", gv_layout, ".svg")
                save_to_path = joinpath(test_imgs_path, test_imgs_name)

                # Create an instance of the model
                model_to_draw = GraphPPL.create_model(model())

                # Generate the DOT code and save the image to the specified file for later analysis
                GraphViz.load(model_to_draw, layout = gv_layout, strategy = gv_strategy, save_to = save_to_path)

                # Check if the file was created
                mktemp() do path, io
                    GraphViz.load(model_to_draw, layout = gv_layout, strategy = gv_strategy, save_to = path)
                    @test isfile(path)
                end
            end
        end
    end
end
