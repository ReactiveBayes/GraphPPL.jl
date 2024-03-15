@testitem "NodeCreatedByPlugin: model with the plugin" begin
    using Distributions

    import GraphPPL:
        NodeCreatedByPlugin,
        EmptyCreatedBy,
        CreatedBy,
        NodeCreationOptions,
        PluginsCollection,
        add_atomic_factor_node!,
        create_model,
        getcontext,
        hasextra,
        getextra

    include("../testutils.jl")

    model = create_test_model(plugins = PluginsCollection(NodeCreatedByPlugin()))
    ctx = getcontext(model)

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(), Normal)

        @test hasextra(nodedata, :created_by)
        @test getextra(nodedata, :created_by) === CreatedBy(EmptyCreatedBy)
    end

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(created_by = :(x ~ Normal(0, 1))), Normal)

        @test hasextra(nodedata, :created_by)

        io = IOBuffer()

        show(io, getextra(nodedata, :created_by))

        @test String(take!(io)) == "x ~ Normal(0, 1)"
    end

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(
            model, ctx, NodeCreationOptions(created_by = () -> :(x ~ Normal(0, 1))), Normal
        )

        @test hasextra(nodedata, :created_by)

        io = IOBuffer()

        show(io, getextra(nodedata, :created_by))

        @test String(take!(io)) == "x ~ Normal(0, 1)"
    end
end

@testitem "NodeCreatedByPlugin: model without the plugin" begin
    using Distributions

    import GraphPPL:
        NodeCreatedByPlugin,
        EmptyCreatedBy,
        CreatedBy,
        NodeCreationOptions,
        PluginsCollection,
        add_atomic_factor_node!,
        create_model,
        getcontext,
        hasextra,
        getextra

    include("../testutils.jl")

    model = create_test_model(plugins = PluginsCollection())
    ctx = getcontext(model)

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(), Normal)
        @test !hasextra(nodedata, :created_by)
    end

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(created_by = :(x ~ Normal(0, 1))), Normal)
        @test !hasextra(nodedata, :created_by)
    end

    @testset begin
        label, nodedata, properties = add_atomic_factor_node!(
            model, ctx, NodeCreationOptions(created_by = () -> :(x ~ Normal(0, 1))), Normal
        )
        @test !hasextra(nodedata, :created_by)
    end
end

@testitem "Usage with the actual model" begin
    using Distributions

    import GraphPPL:
        create_model,
        with_plugins,
        getcontext,
        add_toplevel_model!,
        factor_nodes,
        as_node,
        hasextra,
        PluginsCollection,
        NodeCreatedByPlugin,
        getextra


    include("../testutils.jl")

    @model function simple_model()
        x ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        z ~ Beta(x, y)
    end

    model = create_model(with_plugins(simple_model(), PluginsCollection(NodeCreatedByPlugin())))

    fnormal = map(label -> model[label], filter(as_node(Normal), model))
    fgamma = map(label -> model[label], filter(as_node(Gamma), model))
    fbeta = map(label -> model[label], filter(as_node(Beta), model))

    io = IOBuffer()

    @test length(fnormal) === 1
    @test hasextra(fnormal[1], :created_by)
    @test repr(getextra(fnormal[1], :created_by)) == "x ~ Normal(0, 1)"

    @test length(fgamma) === 1
    @test hasextra(fgamma[1], :created_by)
    @test repr(getextra(fgamma[1], :created_by)) == "y ~ Gamma(1, 1)"

    @test length(fbeta) === 1
    @test hasextra(fbeta[1], :created_by)
    @test repr(getextra(fbeta[1], :created_by)) == "z ~ Beta(x, y)"
end
