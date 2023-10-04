module test_meta_engine

using ReTestItems

include("model_zoo.jl")

@testitem "FactorMetaDescriptor" begin
    include("model_zoo.jl")
    import GraphPPL: FactorMetaDescriptor, IndexedVariable

    @test FactorMetaDescriptor(Normal, (:x, :k, :w)) isa FactorMetaDescriptor{<:Tuple}
    @test FactorMetaDescriptor(Gamma, nothing) isa FactorMetaDescriptor{Nothing}
end

@testitem "VariableMetaDescriptor" begin
    import GraphPPL: VariableMetaDescriptor, IndexedVariable

    @test VariableMetaDescriptor(IndexedVariable(:x, nothing)) isa VariableMetaDescriptor
    @test_throws MethodError VariableMetaDescriptor(1)

end

@testitem "MetaObject" begin
    include("model_zoo.jl")
    import GraphPPL:
        MetaObject, FactorMetaDescriptor, IndexedVariable, VariableMetaDescriptor


    @test MetaObject(
        FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
        SomeMeta(),
    ) isa MetaObject{<:FactorMetaDescriptor,SomeMeta}
    @test MetaObject(FactorMetaDescriptor(Normal, (:x, :k, :w)), (meta = SomeMeta(),)) isa
          MetaObject{<:FactorMetaDescriptor,<:NamedTuple}
    @test_throws MethodError MetaObject((Normal, (:x, :k, :w)), SomeMeta())

    @test MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), SomeMeta()) isa
          MetaObject{<:VariableMetaDescriptor,SomeMeta}
    @test MetaObject(
        VariableMetaDescriptor(IndexedVariable(:x, nothing)),
        (meta = SomeMeta(),),
    ) isa MetaObject{<:VariableMetaDescriptor,<:NamedTuple}
    @test_throws MethodError MetaObject(:x, SomeMeta())
end

@testitem "MetaSpecification" begin
    import GraphPPL: MetaSpecification

    @test MetaSpecification() isa MetaSpecification
end

@testitem "SpecificSubModelMeta" begin
    include("model_zoo.jl")
    import GraphPPL:
        SpecificSubModelMeta,
        GeneralSubModelMeta,
        MetaSpecification,
        IndexedVariable,
        FactorMetaDescriptor,
        MetaObject

    @test SpecificSubModelMeta(:x, MetaSpecification()) isa SpecificSubModelMeta
    push!(
        SpecificSubModelMeta(:x, MetaSpecification()),
        MetaObject(
            FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
            SomeMeta(),
        ),
    )
    push!(
        SpecificSubModelMeta(:x, MetaSpecification()),
        SpecificSubModelMeta(:y, MetaSpecification()),
    )
    push!(
        SpecificSubModelMeta(:x, MetaSpecification()),
        GeneralSubModelMeta(gcv, MetaSpecification()),
    )
end

@testitem "GeneralSubModelMeta" begin
    include("model_zoo.jl")
    import GraphPPL:
        SpecificSubModelMeta,
        GeneralSubModelMeta,
        MetaSpecification,
        IndexedVariable,
        FactorMetaDescriptor,
        MetaObject

    @test GeneralSubModelMeta(gcv, MetaSpecification()) isa GeneralSubModelMeta
    push!(
        GeneralSubModelMeta(gcv, MetaSpecification()),
        MetaObject(
            FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
            SomeMeta(),
        ),
    )
    push!(
        GeneralSubModelMeta(gcv, MetaSpecification()),
        SpecificSubModelMeta(:y, MetaSpecification()),
    )
    push!(
        GeneralSubModelMeta(gcv, MetaSpecification()),
        GeneralSubModelMeta(gcv, MetaSpecification()),
    )

end

@testitem "SubModelMeta" begin
    include("model_zoo.jl")
    import GraphPPL: SubModelMeta, SpecificSubModelMeta, GeneralSubModelMeta
    @test SubModelMeta(:x) isa SpecificSubModelMeta
    @test SubModelMeta(gcv) isa GeneralSubModelMeta
end

@testitem "apply!(::Model, ::Context, ::MetaObject)" begin
    include("model_zoo.jl")
    import GraphPPL:
        apply!,
        node_options,
        IndexedVariable,
        MetaObject,
        getcontext,
        FactorMetaDescriptor,
        VariableMetaDescriptor,
        SomeMeta

    # Test apply for a FactorMeta over a single factor
    model = create_terminated_model(simple_model)
    context = getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(
            NormalMeanVariance,
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        ),
        SomeMeta(),
    )
    apply!(model, context, meta)
    node = first(
        intersect(
            GraphPPL.neighbors(model, context[:x]),
            GraphPPL.neighbors(model, context[:y]),
        ),
    )
    @test node_options(model[node])[:meta] == SomeMeta()

    # Test apply for a FactorMeta over a single factor where variables are not specified
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, nothing), SomeMeta())
    apply!(model, context, meta)
    @test node_options(model[node])[:meta] == SomeMeta()

    # Test apply for a FactorMeta over a vector of factors
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), SomeMeta())
    apply!(model, context, meta)
    for node in intersect(
        GraphPPL.neighbors(model, context[:x]),
        GraphPPL.neighbors(model, context[:y]),
    )
        @test node_options(model[node])[:meta] == SomeMeta()
    end

    # Test apply for a FactorMeta over a vector of factors without specifying variables
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, nothing), SomeMeta())
    apply!(model, context, meta)
    for node in intersect(
        GraphPPL.neighbors(model, context[:x]),
        GraphPPL.neighbors(model, context[:y]),
    )
        @test node_options(model[node])[:meta] == SomeMeta()
    end

    # Test apply for a FactorMeta over a single factor with NamedTuple as meta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(
            NormalMeanVariance,
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        ),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    node = first(
        intersect(
            GraphPPL.neighbors(model, context[:x]),
            GraphPPL.neighbors(model, context[:y]),
        ),
    )
    @test node_options(model[node])[:meta] == SomeMeta()
    @test node_options(model[node])[:other] == 1

    # Test apply for a FactorMeta over a single factor with NamedTuple as meta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(NormalMeanVariance, nothing),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    node = first(
        intersect(
            GraphPPL.neighbors(model, context[:x]),
            GraphPPL.neighbors(model, context[:y]),
        ),
    )
    @test node_options(model[node])[:meta] == SomeMeta()
    @test node_options(model[node])[:other] == 1

    # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(
            NormalMeanVariance,
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        ),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    for node in intersect(
        GraphPPL.neighbors(model, context[:x]),
        GraphPPL.neighbors(model, context[:y]),
    )
        @test node_options(model[node])[:meta] == SomeMeta()
        @test node_options(model[node])[:other] == 1
    end

    # Test apply for a FactorMeta over a factor that is specified by an Index
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(
            NormalMeanVariance,
            (IndexedVariable(:x, 1), IndexedVariable(:y, nothing)),
        ),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    node = first(
        intersect(
            GraphPPL.neighbors(model, context[:x][1]),
            GraphPPL.neighbors(model, context[:y]),
        ),
    )
    @test node_options(model[node])[:meta] == SomeMeta()
    @test node_options(model[node])[:other] == 1
    other_node = first(
        intersect(
            GraphPPL.neighbors(model, context[:x][3]),
            GraphPPL.neighbors(model, context[:y]),
        ),
    )
    @test !haskey(model[other_node].options, :meta)

    # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(NormalMeanVariance, nothing),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    for node in intersect(
        GraphPPL.neighbors(model, context[:x]),
        GraphPPL.neighbors(model, context[:y]),
    )
        @test node_options(model[node])[:meta] == SomeMeta()
        @test node_options(model[node])[:other] == 1
    end

    # Test that setting q in NamedTuple throws an ErrorException
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(NormalMeanVariance, (:x, :y)),
        (meta = SomeMeta(), q = 1),
    )
    @test_throws ErrorException apply!(model, context, meta)

    # Test that setting q in NamedTuple throws an ErrorException
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        FactorMetaDescriptor(NormalMeanVariance, nothing),
        (meta = SomeMeta(), q = 1),
    )
    @test_throws ErrorException apply!(model, context, meta)

    # Test apply for a VariableMeta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), SomeMeta())
    apply!(model, context, meta)
    @test node_options(model[context[:x]])[:meta] == SomeMeta()

    # Test apply for a VariableMeta with NamedTuple as meta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        VariableMetaDescriptor(IndexedVariable(:x, nothing)),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    @test node_options(model[context[:x]])[:meta] == SomeMeta()

    # Test apply for a VariableMeta with NamedTuple as meta
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        VariableMetaDescriptor(IndexedVariable(:x, nothing)),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    @test model[context[:x][1]].options[:meta] == SomeMeta()
    @test model[context[:x][2]].options[:meta] == SomeMeta()
    @test model[context[:x][3]].options[:meta] == SomeMeta()

    # Test apply for a VariableMeta with NamedTuple as meta
    model = create_terminated_model(vector_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        VariableMetaDescriptor(IndexedVariable(:x, nothing)),
        (meta = SomeMeta(), other = 1),
    )
    apply!(model, context, meta)
    @test model[context[:x][1]].options[:meta] == SomeMeta()
    @test model[context[:x][1]].options[:other] == 1
    @test model[context[:x][2]].options[:meta] == SomeMeta()
    @test model[context[:x][2]].options[:other] == 1
    @test model[context[:x][3]].options[:meta] == SomeMeta()
    @test model[context[:x][3]].options[:other] == 1

    # Test apply for a VariableMeta with NamedTuple as meta containing q
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    meta = MetaObject(
        VariableMetaDescriptor(IndexedVariable(:x, nothing)),
        (meta = SomeMeta(), q = 1),
    )
    @test_throws ErrorException apply!(model, context, meta)
end

@testitem "save_meta!(::Model, ::NodeLabel, ::MetaObject)" begin
    include("model_zoo.jl")
    import GraphPPL:
        save_meta!,
        node_options,
        IndexedVariable,
        MetaObject,
        getcontext,
        FactorMetaDescriptor,
        VariableMetaDescriptor,
        SomeMeta,
        neighbors,
        node_options

    # Test save_meta! for a FactorMeta over a single factor
    model = create_terminated_model(simple_model)
    context = getcontext(model)
    node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
    meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), SomeMeta())
    save_meta!(model, node, meta)
    @test node_options(model[node])[:meta] == SomeMeta()

    # Test save_meta! for a FactorMeta with a NamedTuple as meta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
    meta = MetaObject(
        FactorMetaDescriptor(NormalMeanVariance, (:x, :y)),
        (meta = SomeMeta(), other = 1),
    )
    save_meta!(model, node, meta)
    @test node_options(model[node])[:meta] == SomeMeta()
    @test node_options(model[node])[:other] == 1

    # Test save_meta! for a FactorMeta where we try to specify q in the meta
    model = create_terminated_model(simple_model)
    context = GraphPPL.getcontext(model)
    node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
    meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), (q = 1,))
    @test_throws ErrorException save_meta!(model, node, meta)

end
end
