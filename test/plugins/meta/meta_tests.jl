@testitem "@meta macro pipeline" begin
    using GraphPPL

    import GraphPPL: getextra, hasextra, PluginsCollection, MetaPlugin, apply_meta!

    include("../../model_zoo.jl")

    # Test constraints macro with single variables and no nesting
    metaspec = @meta begin
        Normal(x, y, z) -> SomeMeta()
        x -> SomeMeta()
        y -> (meta = SomeMeta(), other = 1)
    end
    model = create_terminated_model(simple_model; plugins = PluginsCollection(MetaPlugin(metaspec)))
    ctx = GraphPPL.getcontext(model)

    @test !hasextra(model[ctx[NormalMeanVariance, 1]], :meta)
    @test getextra(model[ctx[NormalMeanVariance, 2]], :meta) == SomeMeta()

    @test getextra(model[ctx[:x]], :meta) == SomeMeta()
    @test getextra(model[ctx[:y]], :meta) == SomeMeta()
    @test getextra(model[ctx[:y]], :other) == 1

    # Test meta macro with single variables and no nesting
    metaobj = @meta begin
        Gamma(w) -> SomeMeta()
    end
    model = create_terminated_model(outer; plugins = PluginsCollection(MetaPlugin(metaobj)))
    ctx = GraphPPL.getcontext(model)

    for node in filter(GraphPPL.as_node(Gamma) & GraphPPL.as_context(outer), model)
        @test getextra(model[node], :meta) == SomeMeta()
    end

    # Test meta macro with nested model
    metaobj = @meta begin
        for meta in inner
            α -> SomeMeta()
        end
    end
    model = create_terminated_model(outer; plugins = PluginsCollection(MetaPlugin(metaobj)))
    ctx = GraphPPL.getcontext(model)

    @test getextra(model[ctx[:y]], :meta) == SomeMeta()

    # Test with specifying specific submodel
    metaobj = @meta begin
        for meta in (child_model, 1)
            Normal(in, out) -> SomeMeta()
        end
    end
    model = create_terminated_model(parent_model; plugins = PluginsCollection(MetaPlugin(metaobj)))
    ctx = GraphPPL.getcontext(model)

    @test getextra(model[ctx[child_model, 1][NormalMeanVariance, 1]], :meta) == SomeMeta()
    for i in 2:99
        @test !hasextra(model[ctx[child_model, i][NormalMeanVariance, 1]], :meta)
    end

    # Test with specifying general submodel
    metaobj = @meta begin
        for meta in child_model
            Normal(in, out) -> SomeMeta()
        end
    end
    model = create_terminated_model(parent_model; plugins = PluginsCollection(MetaPlugin(metaobj)))
    ctx = GraphPPL.getcontext(model)

    for node in filter(GraphPPL.as_node(NormalMeanVariance) & GraphPPL.as_context(child_model), model)
        @test getextra(model[node], :meta) == SomeMeta()
    end
end
