@testitem "NodeCreatedByPlugin: model with the plugin" begin
    using Distributions

    import GraphPPL: NodeCreatedByPlugin, EmptyCreatedBy, CreatedBy, NodeCreationOptions, PluginsCollection, add_atomic_factor_node!, create_model, getcontext, hasextra, getextra

    model = create_model(plugins = PluginsCollection(NodeCreatedByPlugin()))
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
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(created_by = () -> :(x ~ Normal(0, 1))), Normal)

        @test hasextra(nodedata, :created_by)

        io = IOBuffer()

        show(io, getextra(nodedata, :created_by))

        @test String(take!(io)) == "x ~ Normal(0, 1)"
    end
end

@testitem "NodeCreatedByPlugin: model without the plugin" begin
    using Distributions

    import GraphPPL: NodeCreatedByPlugin, EmptyCreatedBy, CreatedBy, NodeCreationOptions, PluginsCollection, add_atomic_factor_node!, create_model, getcontext, hasextra, getextra

    model = create_model(plugins = PluginsCollection())
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
        label, nodedata, properties = add_atomic_factor_node!(model, ctx, NodeCreationOptions(created_by = () -> :(x ~ Normal(0, 1))), Normal)
        @test !hasextra(nodedata, :created_by)
    end
end