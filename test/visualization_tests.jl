@testitem "Coin Toss Model: generate DOT and save to file" begin
    using GraphPPL
    using RxInfer
    using Distributions
    using ReTestItems
    using GraphViz

    include("test_models.jl") # containing a suite of various model definitions

    # test params for layout and strategy combinations
    layouts = ["dot", "neato"]
    strategies = [:bfs, :simple]

    test_imgs_path = "test/test_imgs"
    if !isdir(test_imgs_path)
        mkdir(test_imgs_path)
    end

    Coin_path = "$(test_imgs_path)/Coin"
    if !isdir(Coin_path)
        mkdir(Coin_path)
    end
    
    # for each combination of layout and strategy
    for gv_layout in layouts
        for gv_strategy in strategies
            model_name = "coin_model"
            test_imgs_path = "test/test_imgs/Coin"
            save_to_path = "$(test_imgs_path)/$(model_name)_$(gv_strategy)_itr_$(gv_layout).pdf"
            
            # Create an instance of the model
            coin_gppl_model = create_coin_model()

            # Generate the DOT code and save the image to the specified file
            gen_dot_coin_result = GraphViz.load(
                coin_gppl_model,
                layout = gv_layout,
                strategy = gv_strategy,
                save_to = save_to_path
            )
            
            # Check if the file was created
            @test isfile(save_to_path)
        end
    end

    # delete all temporarily created files and directories
    if isdir("test/test_imgs")
        rm("test/test_imgs", recursive = true)
    end

end


@testitem "HMM Model: generate DOT and save to file" begin
    using GraphPPL
    using RxInfer
    using Distributions
    using ReTestItems
    using GraphViz

    include("test_models.jl") # containing a suite of various model definitions

    # test params for layout and strategy combinations
    layouts = ["dot", "neato"]
    strategies = [:bfs, :simple]

    test_imgs_path = "test/test_imgs"
    if !isdir(test_imgs_path)
        mkdir(test_imgs_path)
    end

    hmm_path = "$(test_imgs_path)/HMM"
    if !isdir(hmm_path)
        mkdir(hmm_path)
    end
    
    # for each combination of layout and strategy
    for gv_layout in layouts
        for gv_strategy in strategies
            model_name = "hmm"
            test_imgs_path = "test/test_imgs/HMM"
            save_to_path = "$(test_imgs_path)/$(model_name)_$(gv_strategy)_itr_$(gv_layout).pdf"
            
            # Create an instance of the model
            hmm_gppl_model = create_hmm_model()

            # Generate the DOT code and save the image to the specified file
            gen_dot_hmm_result = GraphViz.load(
                hmm_gppl_model,
                layout = gv_layout,
                strategy = gv_strategy,
                save_to = save_to_path
            )
            
            # Check if the file was created
            @test isfile(save_to_path)
        end
    end

    # delete all temporarily created files and directories
    if isdir("test/test_imgs")
        rm("test/test_imgs", recursive = true)
    end
    
end


@testitem "LAR Model: generate DOT and save to file" begin
    using GraphPPL
    using RxInfer
    using Distributions
    using ReTestItems
    using GraphViz

    include("test_models.jl") # containing a suite of various model definitions

    # test params for layout and strategy combinations
    layouts = ["dot", "neato"]
    strategies = [:bfs, :simple]

    test_imgs_path = "test/test_imgs"
    if !isdir(test_imgs_path)
        mkdir(test_imgs_path)
    end

    lar_path = "$(test_imgs_path)/LAR"
    if !isdir(lar_path)
        mkdir(lar_path)
    end
    
    # for each combination of layout and strategy
    for gv_layout in layouts
        for gv_strategy in strategies
            model_name = "lar_model"
            test_imgs_path = "test/test_imgs/LAR"
            save_to_path = "$(test_imgs_path)/$(model_name)_$(gv_strategy)_itr_$(gv_layout).pdf"
            
            # Create an instance of the model
            lar_gppl_model = create_lar_model()

            # Generate the DOT code and save the image to the specified file
            gen_dot_lar_result = GraphViz.load(
                lar_gppl_model,
                layout = gv_layout,
                strategy = gv_strategy,
                save_to = save_to_path
            )
            
            # Check if the file was created
            @test isfile(save_to_path)
        end
    end

    # delete all temporarily created files and directories
    if isdir("test/test_imgs")
        rm("test/test_imgs", recursive = true)
    end
    
end


@testitem "Drone Model: generate DOT and save to file" begin
    using GraphPPL
    using RxInfer
    using Distributions
    using ReTestItems
    using GraphViz

    include("test_models.jl") # containing a suite of various model definitions

    # test params for layout and strategy combinations
    layouts = ["dot", "neato"]
    strategies = [:bfs, :simple]

    test_imgs_path = "test/test_imgs"
    if !isdir(test_imgs_path)
        mkdir(test_imgs_path)
    end

    drone_path = "$(test_imgs_path)/Drone"
    if !isdir(drone_path)
        mkdir(drone_path)
    end
    
    # for each combination of layout and strategy
    for gv_layout in layouts
        for gv_strategy in strategies
            model_name = "drone_model"
            test_imgs_path = "test/test_imgs/Drone"
            save_to_path = "$(test_imgs_path)/$(model_name)_$(gv_strategy)_itr_$(gv_layout).pdf"
            
            # Create an instance of the model
            drone_gppl_model = create_drone_nav_model()

            # Generate the DOT code and save the image to the specified file
            gen_dot_drone_result = GraphViz.load(
                drone_gppl_model,
                layout = gv_layout,
                strategy = gv_strategy,
                save_to = save_to_path
            )
            
            # Check if the file was created
            @test isfile(save_to_path)
        end
    end

    # delete all temporarily created files and directories
    if isdir("test/test_imgs")
        rm("test/test_imgs", recursive = true)
    end
    
end