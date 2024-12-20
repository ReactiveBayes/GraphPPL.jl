@testitem "NodeIdPlugin: model with the plugin" begin
    using Distributions

    import GraphPPL:
        NodeIdPlugin,
        NodeCreationOptions,
        PluginsCollection,
        add_atomic_factor_node!,
        create_model,
        getcontext,
        hasextra,
        getextra,
        create_model,
        with_plugins

    include("../testutils.jl")
    @model function node_with_two_anonymous()
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(0, 1)
        for i in 2:10
            y[i] ~ Normal(0, 1)
            x[i] ~ Normal(y[i - 1] + 1, y[i] + 1)
        end
    end
    model = create_model(with_plugins(node_with_two_anonymous(), GraphPPL.PluginsCollection(NodeIdPlugin())))
    ctx = getcontext(model)

    @testset begin
        nodes = collect(filter(as_node(), model))
        nodedata = getindex.(Ref(model), nodes)
        for node in nodedata
            @test hasextra(node, :id)
        end

        @test length(unique(getextra.(nodedata, :id))) == length(nodedata)
    end
end
