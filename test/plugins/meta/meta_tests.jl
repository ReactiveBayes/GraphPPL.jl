@testitem "Empty meta" begin
    import GraphPPL: MetaPlugin, EmptyMeta

    @test MetaPlugin() == MetaPlugin(EmptyMeta)
    @test MetaPlugin(nothing) == MetaPlugin(EmptyMeta)
end

@testitem "@meta macro pipeline" setup = [TestUtils] begin
    using Distributions
    using GraphPPL

    import GraphPPL: create_model, with_plugins, getextra, hasextra, PluginsCollection, MetaPlugin, apply_meta!

    struct SomeMeta end

    # Test constraints macro with single variables and no nesting
    metaspec = @meta begin
        Normal(x, y, z) -> SomeMeta()
        x -> SomeMeta()
        y -> (meta = SomeMeta(), other = 1)
    end
    model = create_model(with_plugins(TestUtils.simple_model(), PluginsCollection(MetaPlugin(metaspec))))
    ctx = GraphPPL.getcontext(model)

    @test !hasextra(model[ctx[TestUtils.NormalMeanVariance, 1]], :meta)
    @test getextra(model[ctx[TestUtils.NormalMeanVariance, 2]], :meta) == SomeMeta()

    @test getextra(model[ctx[:x]], :meta) == SomeMeta()
    @test getextra(model[ctx[:y]], :meta) == SomeMeta()
    @test getextra(model[ctx[:y]], :other) == 1

    # Test meta macro with single variables and no nesting
    metaobj = @meta begin
        Gamma(w) -> SomeMeta()
    end
    model = create_model(with_plugins(TestUtils.outer(), PluginsCollection(MetaPlugin(metaobj))))
    ctx = GraphPPL.getcontext(model)

    for node in filter(GraphPPL.as_node(Gamma) & GraphPPL.as_context(TestUtils.outer), model)
        @test getextra(model[node], :meta) == SomeMeta()
    end

    # Test meta macro with nested model
    metaobj = @meta begin
        for meta in TestUtils.inner
            α -> SomeMeta()
        end
    end
    model = create_model(with_plugins(TestUtils.outer(), PluginsCollection(MetaPlugin(metaobj))))
    ctx = GraphPPL.getcontext(model)

    @test getextra(model[ctx[:y]], :meta) == SomeMeta()

    # Test with specifying specific submodel
    metaobj = @meta begin
        for meta in (TestUtils.child_model, 1)
            Normal(in, out) -> SomeMeta()
        end
    end
    model = create_model(with_plugins(TestUtils.parent_model(), PluginsCollection(MetaPlugin(metaobj))))
    ctx = GraphPPL.getcontext(model)

    @test getextra(model[ctx[TestUtils.child_model, 1][TestUtils.NormalMeanVariance, 1]], :meta) == SomeMeta()
    for i in 2:99
        @test !hasextra(model[ctx[TestUtils.child_model, i][TestUtils.NormalMeanVariance, 1]], :meta)
    end

    # Test with specifying general submodel
    metaobj = @meta begin
        for meta in TestUtils.child_model
            Normal(in, out) -> SomeMeta()
        end
    end
    model = create_model(with_plugins(TestUtils.parent_model(), PluginsCollection(MetaPlugin(metaobj))))
    ctx = GraphPPL.getcontext(model)

    for node in filter(GraphPPL.as_node(TestUtils.NormalMeanVariance) & GraphPPL.as_context(TestUtils.child_model), model)
        @test getextra(model[node], :meta) == SomeMeta()
    end
end

@testitem "Meta setting via the `where` block" setup = [TestUtils] begin
    using Distributions

    TestUtils.@model function some_model()
        x ~ Beta(1.0, 2.0) where {meta = "Hello, world!"}
    end

    model = GraphPPL.create_model(GraphPPL.with_plugins(some_model(), GraphPPL.PluginsCollection(GraphPPL.MetaPlugin())))
    ctx   = GraphPPL.getcontext(model)
    node  = model[ctx[Beta, 1]]

    @test GraphPPL.getextra(node, :meta) == "Hello, world!"
end

@testitem "Meta should save source code " begin
    using Distributions

    meta = @meta begin
        Normal(in, out) -> 1
    end

    source = GraphPPL.source_code(meta)
    # Test key components rather than exact string match
    @test occursin("Normal(in, out)", source)
    @test occursin("1", source)
    @test occursin("->", source)

    @meta function make_meta(a, b, c)
        Normal(in, out) -> 1
    end

    meta_from_function = make_meta(1, 2, 3)
    source = GraphPPL.source_code(meta_from_function)
    # Test key components rather than exact string match
    @test occursin("function make_meta(a, b, c)", source)
    @test occursin("Normal(in, out)", source)
    @test occursin("1", source)
    @test occursin("->", source)
end
